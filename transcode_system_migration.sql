/*
This script migrates as much configuration as possible from the old transcode system to the new transcode system.

Assumptions:
	- This script is run against a 5.10 environment
	- No manual changes have been made to any formats after upgrading the targeted environment to 5.10.

Things to be aware of:
	- Since this script changes the configuration of the targeted environment,
	  please ensure that you handle the changes in Configuration Management after having run this script.
*/



-- Start transaction to ensure that the migration is atomic.
BEGIN TRANSACTION
BEGIN TRY

SET NOCOUNT ON;
    
DECLARE @mediaFormatId INT,
    @mediaFormatTypeId INT,
    @name NVARCHAR(255),
    @downloadReplaceMask NVARCHAR(MAX),
    @audioBitrate INT,
    @videoBitrate INT,
    @width INT,
    @height INT,
    @settings NVARCHAR(1024),
    @extension NVARCHAR(10),
    @details NVARCHAR(MAX),
    @formatId INT,
    @compressionLevel INT,
    @immediatelyGeneratedFor NVARCHAR(MAX);

-- Create temp table with media formats to process.
CREATE TABLE #mediaFormatsToProcess(
    mediaFormatId INT,
    mediaFormatTypeId INT,
    name NVARCHAR(255),
    downloadReplaceMask NVARCHAR(MAX),
    audioBitrate INT,
    videoBitrate INT,
    width INT,
    height INT,
    settings NVARCHAR(1024)
);

-- Create temp table for keeping track of the migrated formats.
CREATE TABLE #migratedFormats(
    mediaFormatId INT,
    formatId INT,
    extension NVARCHAR(8),
    details NVARCHAR(MAX)
);

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Thumbnail';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = 'e579a06d-ea32-451f-a3d3-b937224c2ffa');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[0]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'webp', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Large Thumbnail';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = '7fb6d99b-9d25-4fb3-831f-b6c51ac08782');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[0]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'webp', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'PDF';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = 'ad44feb1-7038-42a3-a56a-453c76eec8c0');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[5,8,9,14,100,101,102,103,105,106,107,108,111,112]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'pdf', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Video Preview';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = '8bbd835f-80de-460e-bd68-23ef8cc545b4');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[1]'
    WHERE Id=@formatId;
    
    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'mp4', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Audio Preview';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = '75a39459-ba5f-46aa-897b-3cb915a91c70');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[2]'
    WHERE Id=@formatId;
    
    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'mp3', @details);
END


-- Try migrating each media format that isn't already migrated.
INSERT INTO #mediaFormatsToProcess
SELECT mf.media_formatid, mf.media_format_typeid, mfl.medianame, mf.download_replace_mask,
       mf.audiobitrate, mf.videobitrate, mf.width, mf.height, mf.settings
FROM [dbo].[media_format] mf
JOIN [dbo].[media_format_language] mfl ON mf.media_formatid=mfl.media_formatid
WHERE mf.mapped_to_format_id IS NULL AND mfl.languageid=3;

WHILE(EXISTS(SELECT NULL FROM #mediaFormatsToProcess))
BEGIN
    SELECT TOP 1 
           @mediaFormatId=mediaFormatId,
           @mediaFormatTypeId=mediaFormatTypeId,
           @name=name,
           @downloadReplaceMask=downloadReplaceMask,
           @audioBitrate=audioBitrate,
           @videoBitrate=videoBitrate,
           @width=width,
           @height=height,
           @settings=settings
    FROM #mediaFormatsToProcess;
    DELETE FROM #mediaFormatsToProcess WHERE mediaFormatId=@mediaFormatId;

    IF EXISTS(SELECT NULL FROM [dbo].[Formats] WHERE [Name]=@name)
    BEGIN
        print 'Can not migrate the media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + ' since a format with the name "' + @name + '" already exists';
    CONTINUE;
    END
    
    -- Get the extension of the media format.
    SELECT TOP 1 @extension=extension FROM [dbo].[media_format_type_extension] WHERE media_format_typeid=@mediaFormatTypeId;
    
    IF @extension IN ('jpg', 'jpeg', 'png', 'webp', 'avif', 'tif', 'tiff') AND (@settings IS NULL OR @settings='')
    BEGIN
        print 'No ImageMagick command is available for the image media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + '. ' +
              'Can only migrate image media formats with ImageMagick commands.';
        CONTINUE;
    END
       
    -- Escape backslashes and double-quotes to ensure that the corresponding string is a valid JSON string.
    SET @settings = REPLACE(@settings, '\', '\\');
    SET @settings = REPLACE(@settings, '"', '\u0022');

    -- Get the new format details.
    IF @extension='jpg' OR @extension='jpeg'
    BEGIN
        SET @extension='jpeg';
        SET @details = '{"type":"JpegImageFormat",' +
                        '"BackgroundColor":"transparent",' + 
                        '"ColorSpace":0,' + 
                        '"Quality":0,' +
                        '"TargetMaxSize":null,' + 
                        '"Interlace":true,' +
                        '"CropWidth":0,' + 
                        '"CropHeight":0,' + 
                        '"CropPosition":4,' + 
                        '"Clip":false,' + 
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' + 
                        '"AutoOrient":true,' + 
                        '"RemoveFileMetadata":false,' + 
                        '"WatermarkAssetId":0,' + 
                        '"WatermarkAssetExtension":"",' + 
                        '"WatermarkPosition":4,' + 
                        '"WatermarkCoveragePercentage":0,' + 
                        '"WatermarkOffsetX":0,' + 
                        '"WatermarkOffsetY":0,' + 
                        '"WatermarkOpacityPercentage":0,' + 
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' + 
                        '"Width":0,' + 
                        '"ResizeMode":2,' + 
                        '"BackgroundWidth":0,' + 
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='png'
    BEGIN
        SET @details = '{"type":"PngImageFormat",' +
                        '"ColorSpace":0,' + 
                        '"CompressionLevel":7,' +
                        '"Interlace":true,' +
                        '"BackgroundColor":"transparent",' + 
                        '"CropWidth":0,' + 
                        '"CropHeight":0,' + 
                        '"CropPosition":4,' + 
                        '"Clip":false,' + 
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' + 
                        '"AutoOrient":true,' + 
                        '"RemoveFileMetadata":false,' + 
                        '"WatermarkAssetId":0,' + 
                        '"WatermarkAssetExtension":"",' + 
                        '"WatermarkPosition":4,' + 
                        '"WatermarkCoveragePercentage":0,' + 
                        '"WatermarkOffsetX":0,' + 
                        '"WatermarkOffsetY":0,' + 
                        '"WatermarkOpacityPercentage":0,' + 
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' + 
                        '"Width":0,' + 
                        '"ResizeMode":2,' + 
                        '"BackgroundWidth":0,' + 
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='webp'
    BEGIN
        SET @details = '{"type":"WebPImageFormat",' +
                        '"ColorSpace":0,' + 
                        '"Quality":0,' +
                        '"BackgroundColor":"transparent",' + 
                        '"CropWidth":0,' + 
                        '"CropHeight":0,' + 
                        '"CropPosition":4,' + 
                        '"Clip":false,' + 
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' + 
                        '"AutoOrient":true,' + 
                        '"RemoveFileMetadata":false,' + 
                        '"WatermarkAssetId":0,' + 
                        '"WatermarkAssetExtension":"",' + 
                        '"WatermarkPosition":4,' + 
                        '"WatermarkCoveragePercentage":0,' + 
                        '"WatermarkOffsetX":0,' + 
                        '"WatermarkOffsetY":0,' + 
                        '"WatermarkOpacityPercentage":0,' + 
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' + 
                        '"Width":0,' + 
                        '"ResizeMode":2,' + 
                        '"BackgroundWidth":0,' + 
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='avif'
    BEGIN
        SET @details = '{"type":"AvifImageFormat",' +
                        '"ColorSpace":0,' + 
                        '"Quality":0,' +
                        '"BackgroundColor":"transparent",' + 
                        '"CropWidth":0,' + 
                        '"CropHeight":0,' + 
                        '"CropPosition":4,' + 
                        '"Clip":false,' + 
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' + 
                        '"AutoOrient":true,' + 
                        '"RemoveFileMetadata":false,' + 
                        '"WatermarkAssetId":0,' + 
                        '"WatermarkAssetExtension":"",' + 
                        '"WatermarkPosition":4,' + 
                        '"WatermarkCoveragePercentage":0,' + 
                        '"WatermarkOffsetX":0,' + 
                        '"WatermarkOffsetY":0,' + 
                        '"WatermarkOpacityPercentage":0,' + 
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' + 
                        '"Width":0,' + 
                        '"ResizeMode":2,' + 
                        '"BackgroundWidth":0,' + 
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='tif' OR @extension='tiff'
    BEGIN
        SET @extension='tiff';
        SET @details = '{"type":"TiffImageFormat",' +
                        '"ColorSpace":0,' + 
                        '"BackgroundColor":"transparent",' + 
                        '"CropWidth":0,' + 
                        '"CropHeight":0,' + 
                        '"CropPosition":4,' + 
                        '"Clip":false,' + 
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' + 
                        '"AutoOrient":true,' + 
                        '"RemoveFileMetadata":false,' + 
                        '"WatermarkAssetId":0,' + 
                        '"WatermarkAssetExtension":"",' + 
                        '"WatermarkPosition":4,' + 
                        '"WatermarkCoveragePercentage":0,' + 
                        '"WatermarkOffsetX":0,' + 
                        '"WatermarkOffsetY":0,' + 
                        '"WatermarkOpacityPercentage":0,' + 
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' + 
                        '"Width":0,' + 
                        '"ResizeMode":2,' + 
                        '"BackgroundWidth":0,' + 
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='mp3'
    BEGIN
        SET @compressionLevel = CASE
            WHEN @audioBitrate = 0 THEN 4
            WHEN @audioBitrate <= 128000 THEN 6
            WHEN @audioBitrate < 192000 THEN 4
            ELSE 2
        END;
        SET @details = '{"type":"Mp3AudioFormat",' + 
                        '"CompressionLevel":' + CONVERT(NVARCHAR(10), @compressionLevel) + '}';
    END
    ELSE IF @extension='avi'
    BEGIN
        SET @details = '{"type":"AviVideoFormat",' +
                        '"BackgroundColor":"#00000000",' +
                        '"CompressionLevel":23,' + 
                        '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                        '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                        '"ResizeMode":0,' + -- fixed size
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}'
    END
    ELSE IF @extension='mov'
    BEGIN
        SET @details = '{"type":"MovVideoFormat",' +
                        '"BackgroundColor":"#00000000",' +
                        '"CompressionLevel":23,' + 
                        '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                        '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                        '"ResizeMode":0,' + -- fixed size
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}'
    END
    ELSE IF @extension='mp4'
    BEGIN
        SET @details = '{"type":"Mp4VideoFormat",' +
                        '"BackgroundColor":"#00000000",' +
                        '"CompressionLevel":23,' + 
                        '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                        '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                        '"ResizeMode":0,' + -- fixed size
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}'
    END
    ELSE IF @extension='pdf'
        SET @details = '{"type":"PdfFormat"}'
    ELSE
    BEGIN
        print 'The extension "' + @extension + '" is not supported in the new transcode system. ' +
              'Can not migrate the media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + '.';
        CONTINUE;
    END
        
    -- Find asset types to generate renditions of the format for immediately.
    SET @immediatelyGeneratedFor = COALESCE(
        '[' + (SELECT STRING_AGG(assetType, ',') FROM digizuite_assettype_configs_upload_quality WHERE FormatId = @mediaFormatId) + ']', 
        '[]'
    );
        
    -- Make the download replace mask prettier.
    -- This is technically not needed but helps to avoid confusion.
    SET @downloadReplaceMask = (SELECT REPLACE(@downloadReplaceMask, '[%MediaFormatId%]', '[%FormatId%]'));
    SET @downloadReplaceMask = (SELECT REPLACE(@downloadReplaceMask, '[%MediaFormatName%]', '[%FormatName%]'));

    -- Create new format.
    INSERT INTO [dbo].[Formats]([Name],[Description],[Category],[ImmediatelyGeneratedFor],[DownloadReplaceMask],[Details],[CreatedAt],[LastModified])
    VALUES (@name, '', 0, @immediatelyGeneratedFor, NULLIF(@downloadReplaceMask, ''), @details, GETDATE(), GETDATE());

    SELECT @formatId=Id FROM [dbo].[Formats] WHERE [Name]=@name;

    -- Map the old format to the new format.
    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, @extension, @details);
END
DROP TABLE #mediaFormatsToProcess;

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
           MAX(CONVERT(tinyint, d.LaxSecurity)), -- ignore security if at least one destination has LaxSecurity enabled.
           NULL,
           GETDATE()
    FROM [dbo].[asset_filetable] af
        JOIN [dbo].[asset] a on af.assetid = a.assetid
        JOIN [dbo].[digitranscode_destination] d on af.destinationid = d.digitranscode_destinationid
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


-- Prepare special-case migration of source copy media formats.
declare @source_copy_media_format_ids table (media_format_id int primary key);
insert into @source_copy_media_format_ids (media_format_id)
SELECT target_media_formatid
FROM dbo.media_transcode
WHERE source_media_formatid IS NULL
  AND progid = 'DigiJobs.JobFileCopy';

-- Ensures that we create a SourceFormat rendition with `IgnoreSecurity = true` for
-- each source copy that is available on a destination with LaxSecurity enabled.
INSERT INTO [dbo].[Renditions]([FormatId], [AssetId], [FilePath], [FileSize], [Fingerprint], [State],
    [IgnoreSecurity], [ErrorMessage], [LastModified], [LastAccessed], [ExecutionTime])
SELECT -1,
       af.assetid,
       'assets/' + MIN(af.fileName),
       MAX(af.Size),
       COALESCE(UPPER(MIN(a.hashsha1)), '') + '-source-' + '{"type":"SourceFormat"}',
       2,
       1,
       NULL,
       GETDATE(),
       GETDATE(),
       '00:00:00' as time
FROM [dbo].[asset_filetable] af
    JOIN [dbo].[asset] a on af.assetid = a.assetid
    JOIN [dbo].[digitranscode_destination] d on af.destinationid = d.digitranscode_destinationid
    join @source_copy_media_format_ids s on af.Media_formatid = s.media_format_id
WHERE d.LaxSecurity = 1
  AND NOT EXISTS(SELECT NULL FROM dbo.Renditions WHERE FormatId = -1 AND AssetId = af.assetId)
GROUP BY af.assetid;

-- Map the source copy media formats to the SourceFormat with the id -1.
UPDATE [dbo].[media_format]
SET mapped_to_format_id=-1
WHERE media_formatid IN (SELECT media_format_id FROM @source_copy_media_format_ids);


drop index [asset_filetable_Media_formatid_index] ON [dbo].[asset_filetable];

SET NOCOUNT OFF;

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
