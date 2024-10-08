SELECT af.Media_formatid, af.assetid, af.destinationid
FROM [dbo].[asset_filetable] af
    JOIN [dbo].[digitranscode_destination] d on af.destinationid = d.digitranscode_destinationid
WHERE
    af.Processing = 0 AND
    d.LaxSecurity = 1 AND
    NOT EXISTS(
        SELECT NULL FROM media_format mf
            JOIN Formats f on mf.mapped_to_format_id = f.Id
            CROSS APPLY OPENJSON(f.NoSecurityWhenInChannelFolderIds) NoSecurityChannel
        WHERE mf.media_formatid = af.Media_formatid AND NoSecurityChannel.value = af.destinationid)


