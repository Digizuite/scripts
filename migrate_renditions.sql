/*
 This script migrates renditions from the old transcode system to the new transcode system.
 This script also ensures that download qualities are migrated.
 It is assumed that new formats have already been created and mapped to the old media formats.
 
 Implementation notes:
 - We migrate based on the current format details to ensure that the migrated renditions
   will be valid for the current state of the format. Alternatively, we could have migrated
   based on the mapped media format settings, similar to what is done in `transcode_system_migration`.
   The main advantage of migrating based on the current format details is that we can ensure that
   the renditions are valid for the current state of the format. The main disadvantage is that
   we need to replace escaped unicode characters in the details.
 */


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
    SET details = REPLACE(details, '\u0021', '!')
    WHERE details LIKE '%\u0021%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0023', '#')
    WHERE details LIKE '%\u0023%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0024', '$')
    WHERE details LIKE '%\u0024%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0025', '%')
    WHERE details LIKE '%\u0025%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0026', '&')
    WHERE details LIKE '%\u0026%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0028', '(')
    WHERE details LIKE '%\u0028%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0029', ')')
    WHERE details LIKE '%\u0029%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002A', '*')
    WHERE details LIKE '%\u002A%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002B', '+')
    WHERE details LIKE '%\u002B%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002C', ',')
    WHERE details LIKE '%\u002C%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002D', '-')
    WHERE details LIKE '%\u002D%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002E', '.')
    WHERE details LIKE '%\u002E%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u002F', '/')
    WHERE details LIKE '%\u002F%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003A', ':')
    WHERE details LIKE '%\u003A%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003B', ';')
    WHERE details LIKE '%\u003B%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003C', '<')
    WHERE details LIKE '%\u003C%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003D', '=')
    WHERE details LIKE '%\u003D%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003C', '<')
    WHERE details LIKE '%\u003C%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003F', '?')
    WHERE details LIKE '%\u003F%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u003E', '>')
    WHERE details LIKE '%\u003E%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0040', '@')
    WHERE details LIKE '%\u0040%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u005B', '[')
    WHERE details LIKE '%\u005B%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u005C', '\\')
    WHERE details LIKE '%\u005C%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u005D', ']')
    WHERE details LIKE '%\u005D%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u005E', '^')
    WHERE details LIKE '%\u005E%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u005F', '_')
    WHERE details LIKE '%\u005F%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u0060', '`')
    WHERE details LIKE '%\u0060%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u007B', '{')
    WHERE details LIKE '%\u007B%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u007C', '|')
    WHERE details LIKE '%\u007C%';
    
    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u007D', '}')
    WHERE details LIKE '%\u007D%';

    UPDATE #migratedFormats
    SET details = REPLACE(details, '\u007E', '~')
    WHERE details LIKE '%\u007E%';

    -- Check for unexpected unicode characters.
    IF (SELECT NULL FROM #migratedFormats WHERE REPLACE(details, '\u0022', '"') NOT LIKE '%\u00%')
    BEGIN
        SELECT * FROM #migratedFormats WHERE REPLACE(details, '\u0022', '"') NOT LIKE '%\u00%';
        throw 51000, 'An unexpected unicode character was encountered. Please add the missing unicode character translation', 1;
    END


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