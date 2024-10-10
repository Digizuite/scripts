/*
 Finds the renditions that are no longer publicly available after having migrated 
 from the old transcode system to the new transcode system.
 */

SELECT
    publicly_available.assetid as assetId,
    publicly_available.Media_formatid as mediaFormatId,
    f.Id as formatId,
    f.Name as formatName
FROM (
    -- Get all renditions that were publicly available before the migration.
    SELECT distinct 
        af.assetid, 
        af.Media_formatid
    FROM asset_filetable af
          JOIN [dbo].[digitranscode_destination] d on af.destinationid = d.digitranscode_destinationid
    WHERE Processing = 0 AND d.LaxSecurity = 1) as publicly_available
    JOIN media_format mf ON mf.media_formatid = publicly_available.Media_formatid
    LEFT JOIN Formats f ON f.Id = mf.mapped_to_format_id
-- Filter out the renditions that are still publicly available after the migration.
WHERE NOT EXISTS(
    SELECT NULL FROM asset_layoutfolder alf
        JOIN OPENJSON(f.NoSecurityWhenInChannelFolderIds) no_security_folder
            ON alf.layoutfolderid = no_security_folder.value
    WHERE publicly_available.assetid = alf.assetid
);