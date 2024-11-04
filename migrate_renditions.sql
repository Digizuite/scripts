-- Start transaction to ensure that the migration is atomic.
BEGIN TRANSACTION
BEGIN TRY

    DECLARE @mediaFormatId INT,
        @extension NVARCHAR(10),
        @details NVARCHAR(MAX),
        @formatId INT;

    -- Create temp table for keeping track of the migrated formats.
    CREATE TABLE #migratedFormats(
        mediaFormatId INT,
        formatId INT,
        extension NVARCHAR(8),
        details NVARCHAR(MAX)
    );

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    SELECT
        mf.media_formatid,
        mf.mapped_to_format_id,
        (SELECT TOP 1 extension FROM media_format_type_extension mfte WHERE mfte.media_format_typeid = mf.media_format_typeid),
        F.Details
    FROM media_format mf
    JOIN Formats F on F.Id = mf.mapped_to_format_id
    WHERE mf.mapped_to_format_id is not null
      AND mf.mapped_to_format_id != -1

    -- Ensure that the thumbnail formats are set to be webp.
    UPDATE #migratedFormats
    SET extension = 'webp'
    WHERE formatId IN 
          (SELECT Id 
           FROM Formats 
           WHERE Guid IN ('88c69734-3905-4940-9e1a-851fe2ab10b8', '0a46c385-7b90-4364-bcb0-87265bcc216d');

    -- Ensure that the correct extensions are used.
    UPDATE #migratedFormats
    SET extension = 'jpeg'
    WHERE extension = 'jpg';
    
    UPDATE #migratedFormats
    SET extension = 'tiff'
    WHERE extension = 'tif';

    -- Replace escaped unicode characters in details.
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002B', '+')
    WHERE details LIKE '%\u002B%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003E', '>')
    WHERE details LIKE '%\u003E%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003C', '<')
    WHERE details LIKE '%\u003C%';

    -- Create an index to make the next query operation faster.
    CREATE NONCLUSTERED INDEX [asset_filetable_Media_formatid_index] ON [dbo].[asset_filetable]
    (
     [Media_formatid] ASC,
     [Processing] ASC
    )
    INCLUDE([assetid],[hashsha1],[destinationid],[Size],[fileName]);

    -- Create rendition entries for the migrated formats to avoid re-transcoding.
    WHILE EXISTS(SELECT NULL FROM #migratedFormats)
    BEGIN
        SELECT TOP 1 @mediaFormatId=mediaFormatId, @formatId=formatId, @extension=extension, @details=details FROM #migratedFormats;
        DELETE FROM #migratedFormats WHERE mediaFormatId=@mediaFormatId AND formatId=@formatId;
        
        INSERT INTO [dbo].[Renditions]([FormatId],[AssetId],[FilePath],[FileSize],[Fingerprint],[State],[IgnoreSecurity],[ErrorMessage],[LastModified])
        SELECT @formatId,
               af.assetid,
               'assets/' + MIN(af.fileName),
               MAX(af.Size),
               COALESCE(UPPER(a.hashsha1), '') + '-' + @extension + '-' + @details,
               2,
               0, -- rely on the migration of profiles to IgnoreSecurity instead of hard-coding it on the rendition.
               NULL,
               GETDATE()
        FROM [dbo].[asset_filetable] af
            JOIN [dbo].[asset] a on af.assetid = a.assetid
        WHERE af.Media_formatid = @mediaFormatId
          AND af.Processing = 0
          AND NOT EXISTS(SELECT NULL FROM [dbo].[Renditions] r WHERE r.FormatId = @formatId AND r.AssetId = af.assetid)
        GROUP BY af.assetid, af.Media_formatid, a.hashsha1
        
        
        -- Migrate existing member group download qualities.
        INSERT INTO [dbo].[LoginService_GroupDownloadQualities]([MemberGroupId], [FormatId])
        SELECT q1.MemberGroupId, CONVERT(NVARCHAR(10), @formatId)
        FROM [dbo].[LoginService_GroupDownloadQualities] q1
        WHERE q1.FormatId=CONVERT(NVARCHAR(10), @mediaFormatId) AND
            NOT EXISTS(SELECT NULL FROM [dbo].[LoginService_GroupDownloadQualities] q2
                       WHERE q1.MemberGroupId = q2.MemberGroupId AND q2.FormatId = CONVERT(NVARCHAR(10), @formatId));
        
        DELETE FROM [dbo].[LoginService_GroupDownloadQualities] WHERE FormatId = CONVERT(NVARCHAR(10), @mediaFormatId);
    END

    DROP TABLE #migratedFormats;
    drop index [asset_filetable_Media_formatid_index] ON [dbo].[asset_filetable];
    
    -- Migration was successful, commit the changes.
    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    -- Migration was unsuccessful, rollback the changes.
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @msg NVARCHAR(MAX), @sev INT, @stt INT;
    SET @msg = N'ERROR: Number: ' + CAST(ERROR_NUMBER() as nvarchar(max)) + N', Message: ' + ERROR_MESSAGE();
    SET @sev = ERROR_SEVERITY();
    SET @stt = ERROR_STATE();
    RaisError(@msg, @sev, @stt);
END CATCH