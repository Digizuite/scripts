-- Start transaction to ensure that the migration is atomic.
BEGIN TRANSACTION
BEGIN TRY

    DECLARE 
        @formatId INT,
        @mediaFormatId INT,    
        @mediaFormatTypeId INT,
        @audioBitrate INT,
        @videoBitrate INT,
        @width INT,
        @height INT,
        @compressionLevel INT,
        @settings NVARCHAR(1024),
        @extension NVARCHAR(10),
        @details NVARCHAR(MAX),
        @formatId INT;
            
    -- Create temp table with media formats to process.
    CREATE TABLE #mediaFormatsToProcess(
       formatId INT,
       mediaFormatId INT,
       mediaFormatTypeId INT,
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

    INSERT INTO #mediaFormatsToProcess
    SELECT mf.mapped_to_format_id, mf.media_formatid, mf.media_format_typeid,
           mf.audiobitrate, mf.videobitrate, mf.width, mf.height, mf.settings
    FROM [dbo].[media_format] mf
        JOIN [dbo].[media_format_language] mfl ON mf.media_formatid=mfl.media_formatid
    WHERE mf.mapped_to_format_id IS NOT NULL AND mfl.languageid=3;

    WHILE(EXISTS(SELECT NULL FROM #mediaFormatsToProcess))
    BEGIN
        SELECT TOP 1
            @formatId=formatId,
            @mediaFormatId=mediaFormatId,
            @mediaFormatTypeId=mediaFormatTypeId,
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
                                '"CompressionLevel":' + CONVERT(NVARCHAR(10), @compressionLevel);
        
                if @audioBitrate<>0
                begin
                                set @details = @details + ',"Bitrate":' + CONVERT(NVARCHAR(10), @audioBitrate)
                end
        
                set @details = @details + '}';
        END
        ELSE IF @extension='avi'
        BEGIN
                SET @details = '{"type":"AviVideoFormat",' +
                                '"BackgroundColor":"#00000000",' +
                                '"CompressionLevel":23,';
        
                IF @videoBitrate<>0
                begin
                    set @details = @details +
                                '"VideoBitrate":' + CONVERT(NVARCHAR(10), @videoBitrate) + ',';
                end;
        
        
                IF @audioBitrate<>0
                begin
                    set @details = @details +
                                '"AudioBitrate":' + CONVERT(NVARCHAR(10), @audioBitrate) + ',';
                end;
        
                set @details = @details +
                                '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                                '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                                '"ResizeMode":0,' + -- fixed size
                                '"BackgroundWidth":0,' +
                                '"BackgroundHeight":0' +
                                '}';
        END
        ELSE IF @extension='mov'
        BEGIN
                SET @details = '{"type":"MovVideoFormat",' +
                                '"BackgroundColor":"#00000000",' +
                                '"CompressionLevel":23,';
        
                IF @videoBitrate<>0
                begin
                    set @details = @details +
                                '"VideoBitrate":' + CONVERT(NVARCHAR(10), @videoBitrate) + ',';
                end;
        
        
                IF @audioBitrate<>0
                begin
                    set @details = @details +
                                '"AudioBitrate":' + CONVERT(NVARCHAR(10), @audioBitrate) + ',';
                end;
        
                set @details = @details +
                                '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                                '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                                '"ResizeMode":0,' + -- fixed size
                                '"BackgroundWidth":0,' +
                                '"BackgroundHeight":0' +
                                '}';
        END
        ELSE IF @extension='mp4'
        BEGIN
                SET @details = '{"type":"Mp4VideoFormat",' +
                                '"BackgroundColor":"#00000000",' +
                                '"CompressionLevel":23,';
        
                IF @videoBitrate<>0
                begin
                    set @details = @details +
                                '"VideoBitrate":' + CONVERT(NVARCHAR(10), @videoBitrate) + ',';
                end;
        
        
                IF @audioBitrate<>0
                begin
                    set @details = @details +
                                '"AudioBitrate":' + CONVERT(NVARCHAR(10), @audioBitrate) + ',';
                end;
        
                set @details = @details +
                                '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                                '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                                '"ResizeMode":0,' + -- fixed size
                                '"BackgroundWidth":0,' +
                                '"BackgroundHeight":0' +
                                '}';
        
        END
        ELSE IF @extension='pdf'
                SET @details = '{"type":"PdfFormat"}'
            ELSE
        BEGIN
                print 'The extension "' + @extension + '" is not supported in the new transcode system. ' +
                      'Can not migrate the media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + '.';
        CONTINUE;
        END
        
        INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
        VALUES (@mediaFormatId, @formatId, @extension, @details);
    END


--     INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
--     SELECT
--         mf.media_formatid,
--         mapped_to_format_id,
--         (SELECT TOP 1 extension FROM media_format_type_extension mfte WHERE mfte.media_format_typeid = mf.media_format_typeid),
--         mf.settings
--     FROM media_format mf
--     WHERE mapped_to_format_id is not null
--       AND mapped_to_format_id NOT IN (-1, 50395, 50396);


    -- Ensure that the thumbnail formats have the correct extensions.
    UPDATE #migratedFormats
    SET extension = 'webp'
    WHERE formatId IN (50395, 50396);


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

        /*
        -- Migrate existing member group download qualities.
        INSERT INTO [dbo].[LoginService_GroupDownloadQualities]([MemberGroupId], [FormatId])
        SELECT q1.MemberGroupId, CONVERT(NVARCHAR(10), @formatId)
        FROM [dbo].[LoginService_GroupDownloadQualities] q1
        WHERE q1.FormatId=CONVERT(NVARCHAR(10), @mediaFormatId) AND
            NOT EXISTS(SELECT NULL FROM [dbo].[LoginService_GroupDownloadQualities] q2
                       WHERE q1.MemberGroupId = q2.MemberGroupId AND q2.FormatId = CONVERT(NVARCHAR(10), @formatId));
        
        DELETE FROM [dbo].[LoginService_GroupDownloadQualities] WHERE FormatId = CONVERT(NVARCHAR(10), @mediaFormatId);
        
         */
    END

    DROP TABLE #mediaFormatsToProcess;
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