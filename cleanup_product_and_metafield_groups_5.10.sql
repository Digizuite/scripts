ALTER PROCEDURE [dbo].[DeleteMetafieldGroup]
@itemGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @trancount INT = @@TRANCOUNT;
    /* Only use with DAM update scripts! Also use this with great caution! */

    BEGIN TRY;
    IF @trancount = 0 BEGIN TRANSACTION;
    ELSE SAVE TRANSACTION DeleteMetafieldGroup;

    DECLARE @msg NVARCHAR(MAX);
    DECLARE @metafieldGroupId INT, @metafieldGroupItemId INT, @metafieldItemGuid UNIQUEIDENTIFIER;
    SELECT @metafieldGroupId = img.item_metafield_groupid, @metafieldGroupItemId = item.itemid
    FROM dbo.item_metafield_group img
             INNER JOIN dbo.item_item_metafield_group iimg on img.item_metafield_groupid = iimg.item_metafield_groupid
             INNER JOIN dbo.item on iimg.itemid = item.itemid
    WHERE item.ItemGuid = @itemGuid;

    IF @metafieldGroupId IS NULL
        BEGIN
            RAISERROR(N'MetafieldGroup does not exist', 0, 1);
            IF @trancount = 0 ROLLBACK TRANSACTION;
            RETURN;
        END

    DECLARE @metafields TABLE([itemGuid] UNIQUEIDENTIFIER);
    INSERT INTO @metafields
    SELECT item.ItemGuid
    FROM dbo.item_metafield imf
             INNER JOIN dbo.item_item_metafield iim on imf.item_metafieldid = iim.item_metafieldid
             INNER JOIN dbo.item on iim.itemid = item.itemid
    WHERE imf.item_datatypeid = 65 AND imf.item_metafield_subgroupid = @metafieldGroupId;
    INSERT INTO @metafields
    SELECT item.ItemGuid
    FROM dbo.item_metafield imf
             INNER JOIN dbo.item_item_metafield iim on imf.item_metafieldid = iim.item_metafieldid
             INNER JOIN dbo.item on iim.itemid = item.itemid
    WHERE imf.item_metafield_groupid = @metafieldGroupId;

    SELECT TOP 1 @metafieldItemGuid = [itemGuid] FROM @metafields;
    WHILE @metafieldItemGuid IS NOT NULL
        BEGIN
            EXEC dbo.DeleteMetafield @itemGuid=@metafieldItemGuid;

            DELETE FROM @metafields WHERE [itemGuid] = @metafieldItemGuid;
            SET @metafieldItemGuid = NULL;
            SELECT TOP 1 @metafieldItemGuid = [itemGuid] FROM @metafields;
        END

    UPDATE dbo.Product SET item_metafield_groupid = null WHERE item_metafield_groupid = @metafieldGroupId;
    UPDATE dbo.item SET item_metafield_groupid = null WHERE item_metafield_groupid = @metafieldGroupId;
    DELETE FROM dbo.item_item_metafield_group WHERE [item_metafield_groupid] = @metafieldGroupId;
    DELETE FROM dbo.item_metafield_group WHERE [item_metafield_groupid] = @metafieldGroupId;
    DELETE FROM dbo.item_security WHERE [object_itemid] = @metafieldGroupItemId;
    DELETE FROM dbo.item_metafield_value WHERE [ref_itemid] = @metafieldGroupItemId;
    DELETE FROM dbo.Meta_Value_Version WHERE [Ref_ItemId] = @metafieldGroupItemId;
    DELETE FROM dbo.item WHERE [itemid] = @metafieldGroupItemId;
    SET @msg = N'MetafieldGroup ''' + CAST(@itemGuid AS nvarchar(MAX)) + N''' deleted.';
    RAISERROR(@msg, 0, 1) WITH NOWAIT;

    IF @trancount = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH;
    DECLARE @xstate INT = XACT_STATE();

    IF @xstate = -1 ROLLBACK TRANSACTION;
    IF @xstate = 1 AND @trancount = 0 ROLLBACK TRANSACTION;
    IF @xstate = 1 AND @trancount > 0 ROLLBACK TRANSACTION DeleteMetafieldGroup;

    THROW;
    END CATCH
END
GO


ALTER PROCEDURE [dbo].[DeleteMetafield]
@itemGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @trancount INT = @@TRANCOUNT;
    /* Only use with DAM update scripts! And don't use this with metafields belong to assets (Asset Info etc.) */

    BEGIN TRY;
    IF @trancount = 0 BEGIN TRANSACTION;
    ELSE SAVE TRANSACTION DeleteMetafield;

    DECLARE @msg NVARCHAR(MAX);
    DECLARE @itemsToDelete TABLE([metafieldid] int, [metafield_itemid] int, [datatypeid] int, [metafieldlabelid] int, [metafieldlabel_itemid] int);
    INSERT INTO @itemsToDelete
    SELECT imf.item_metafieldid, imf_item.itemid, imf.item_datatypeid, iml.item_metafield_labelid, iml_item.itemid
    FROM           dbo.item_metafield imf
                       INNER JOIN dbo.item_item_metafield iim on imf.item_metafieldid = iim.item_metafieldid
                       INNER JOIN dbo.item imf_item on iim.itemid = imf_item.itemid
                       INNER JOIN dbo.item_metafield_label iml on imf.item_metafieldid = iml.item_metafieldid
                       INNER JOIN dbo.item_item_metafield_label iiml on iml.item_metafield_labelid = iiml.item_metafield_labelid
                       INNER JOIN dbo.item iml_item on iiml.itemid = iml_item.itemid
    WHERE imf_item.ItemGuid = @itemGuid;

    IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'Metafield does not exist', 0, 1);
            IF @trancount = 0 ROLLBACK TRANSACTION;
            RETURN;
        END

    DECLARE @valueCount BIGINT = 0;
    DELETE FROM dbo.item_metafield_value WHERE [item_metafield_labelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    DELETE FROM dbo.item_metafield_value WHERE [ref_itemid] IN (SELECT [metafield_itemid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    DELETE FROM dbo.item_metafield_value WHERE [ref_itemid] IN (SELECT [metafieldlabel_itemid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    DELETE FROM dbo.item_note_value WHERE [item_metafield_labelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    DELETE FROM dbo.Meta_Value_Version WHERE [LabelId] IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    DELETE FROM dbo.Meta_Value_Version WHERE [Ref_ItemId] IN (SELECT [metafield_itemid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    DELETE FROM dbo.Meta_Value_Version WHERE [Ref_ItemId] IN (SELECT [metafieldlabel_itemid] FROM @itemsToDelete);
    SET @valueCount = @valueCount + @@ROWCOUNT;
    SET @msg = CAST(@valueCount AS nvarchar(MAX)) + N' values deleted.';
    RAISERROR(@msg, 0, 1) WITH NOWAIT;

    DECLARE @treesToDelete TABLE([treevalueid] int, [treevalue_itemid] int);
    INSERT INTO @treesToDelete
    SELECT itv.item_tree_valueid, item.itemid
    FROM dbo.item_tree_value itv
             INNER JOIN dbo.item_item_tree_value iitv on itv.item_tree_valueid = iitv.item_tree_valueid
             INNER JOIN dbo.item on iitv.itemid = item.itemid
    WHERE itv.item_metafield_labelid IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    IF @@ROWCOUNT > 0
        BEGIN;
        DELETE FROM dbo.item_item_tree_value WHERE [item_tree_valueid] IN (SELECT [treevalueid] FROM @treesToDelete);
        DELETE FROM dbo.item_tree_value WHERE [item_tree_valueid] IN (SELECT [treevalueid] FROM @treesToDelete);
        DELETE FROM dbo.item_security WHERE [object_itemid] IN (SELECT [treevalue_itemid] FROM @treesToDelete);
        DELETE FROM dbo.item WHERE [itemid] IN (SELECT [treevalue_itemid] FROM @treesToDelete);
        SET @msg = CAST(@@ROWCOUNT AS nvarchar(MAX)) + N' treevalues deleted.';
        RAISERROR(@msg, 0, 1) WITH NOWAIT;
        END;

    DECLARE @combosToDelete TABLE([combovalueid] int, [combovalue_itemid] int);
    INSERT INTO @combosToDelete
    SELECT icv.item_combo_valueid, item.itemid
    FROM dbo.item_combo_value icv
             INNER JOIN dbo.item_item_combo_value iicv on icv.item_combo_valueid = iicv.item_combo_valueid
             INNER JOIN dbo.item on iicv.itemid = item.itemid
    WHERE icv.item_metafield_labelid IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    IF @@ROWCOUNT > 0
        BEGIN;
        DELETE FROM dbo.item_item_combo_value WHERE [item_combo_valueid] IN (SELECT [combovalueid] FROM @combosToDelete);
        DELETE FROM dbo.item_combo_value WHERE [item_combo_valueid] IN (SELECT [combovalueid] FROM @combosToDelete);
        DELETE FROM dbo.item_security WHERE [object_itemid] IN (SELECT [combovalue_itemid] FROM @combosToDelete);
        DELETE FROM dbo.item WHERE [itemid] IN (SELECT [combovalue_itemid] FROM @combosToDelete);
        SET @msg = CAST(@@ROWCOUNT AS nvarchar(MAX)) + N' combovalues deleted.';
        RAISERROR(@msg, 0, 1) WITH NOWAIT;
        END;

    DELETE FROM dbo.item_item_metafield_label WHERE [item_metafield_labelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    DELETE FROM dbo.item_metafield_reference WHERE [metafield_labelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete)
                                                OR [ref_metafield_labelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete)
                                                OR [lookup_metafieldlabelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    DELETE FROM dbo.item_metafield_label WHERE [item_metafield_labelid] IN (SELECT [metafieldlabelid] FROM @itemsToDelete);
    DELETE FROM dbo.item_security WHERE [object_itemid] IN (SELECT [metafieldlabel_itemid] FROM @itemsToDelete);
    DELETE FROM dbo.item WHERE [itemid] IN (SELECT [metafieldlabel_itemid] FROM @itemsToDelete);
    SET @msg = CAST(@@ROWCOUNT AS nvarchar(MAX)) + N' metafieldlabels deleted.';
    RAISERROR(@msg, 0, 1) WITH NOWAIT;

    DELETE FROM dbo.item_item_metafield WHERE [item_metafieldid] IN (SELECT [metafieldid] FROM @itemsToDelete);
    DELETE FROM dbo.item_metafield WHERE [item_metafieldid] IN (SELECT [metafieldid] FROM @itemsToDelete);
    DELETE FROM dbo.item_security WHERE [object_itemid] IN (SELECT [metafield_itemid] FROM @itemsToDelete);
    DELETE FROM dbo.item WHERE [itemid] IN (SELECT [metafield_itemid] FROM @itemsToDelete);
    SET @msg = N'Metafield ''' + CAST(@itemGuid AS nvarchar(MAX)) + N''' deleted.';
    RAISERROR(@msg, 0, 1) WITH NOWAIT;

    IF @trancount = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH;
    DECLARE @xstate INT = XACT_STATE();
    IF @xstate = -1 ROLLBACK TRANSACTION;
    IF @xstate = 1 AND @trancount = 0 ROLLBACK TRANSACTION;
    IF @xstate = 1 AND @trancount > 0 ROLLBACK TRANSACTION DeleteMetafield;

    THROW;
    END CATCH
END
GO


DECLARE @metafieldGroupGuids TABLE (guid uniqueidentifier not null);
DECLARE @metafieldGroupsToDelete TABLE (guid uniqueidentifier not null);
DECLARE @currentGuid uniqueidentifier, @currentGuidString nvarchar(128);
INSERT INTO @metafieldGroupGuids VALUES
                                     ('4f251d08-0ddf-4e0f-8dd9-7379c66d23ac'), /*Images*/
                                     ('11e7b6c6-8c99-4de3-b022-33c4ff2a64fc'), /*Drawing*/
                                     ('9dbebec4-da6b-46d1-8af5-deae210a1941'), /*Sharing*/
                                     ('205f112c-a91c-42d2-8ded-52cc72a9e9a8'), /*Sharing Tab*/
                                     ('fafe1756-f070-4938-a200-5d7e6de8fd35'), /*LiveRecord*/
                                     ('97df7d0f-0afe-4d8f-820c-884918a44a2d'), /*LiveRecordAsset*/
                                     ('342238e4-29d9-442a-b46a-c39eaa5746ff'), /*LayoutFolder Mediaportal*/
                                     ('7ac2eb94-2fc2-4575-a9fd-036721f5ede6'), /*Ip*/
                                     ('5a38f498-ead9-4a0a-b218-a73f6f32ee39'), /*FrontendGroup*/
                                     ('a66bbf5e-e7d3-4a75-952c-29319ebfdf9d'), /*LayoutFolder Preroll*/
                                     ('4a9fb5c2-7217-4462-82cb-a272f05a6471'), /*Preroll Tab*/
                                     ('9c3d5dfa-bfa4-4f18-b45f-6ddd9fd551d0'), /*LayoutFolder WebTV*/
                                     ('aa04d635-c52d-48e1-b8c1-6952ee1fb1ec'), /*Valid Download Qualities*/
                                     ('7157d5d7-d88b-4fc3-b53f-388102ac3f02'), /*Layoutfolder OfficeConnector*/
                                     ('aa1affbe-b89c-456d-bbd1-416792f9cede'), /*Comments*/
                                     ('35ea4845-ead2-4e01-ba0f-c8da1844e232'), /*FrontendUserUpload*/
                                     ('85996024-fcd3-436e-aeca-02446bebfd68'), /*FrontendUserGroupUpload*/
                                     ('7f5ac61e-5fe0-4caa-a4b2-d1bb64ed6daa'), /*Geotag*/
                                     ('96188a9f-85c5-46fc-83ee-c66835f5d117'), /*Exif*/
                                     ('20dfaf7b-a1a2-4775-a237-262c3a9358dd'), /*Layoutfolder Digizuite™ DigiUpload Mobile*/
                                     ('5a8c0cf9-866a-4d69-8104-42b262afbb80'), /*User Config*/
                                     ('7352526f-5f84-4fac-a5da-e2eb8d586104'), /*Video Commercial*/
                                     ('64525db4-b986-4903-9929-dd11243a2ab1'), /*IPTC*/
                                     ('6bc6c76f-1611-4bec-b2f2-cbbff06422d6'), /*Product Urls DC*/
                                     ('b89bdff1-c619-4b48-a23f-a0c1bc7405e7'), /*Config VP3*/
                                     ('66b26514-43f8-4745-baf8-f47ec7e4ac68'), /*Product Urls VP3*/
                                     ('bdd93ebe-a4c6-4df1-8edb-b170d5b75cf5'), /*Video Slider*/
                                     ('6fa07c1f-071a-4994-952b-59418c5fa7d0'), /*Config MM4*/
                                     ('f2da9799-3faf-453e-bec1-70b9e107bc8c'), /*Product Urls MM4*/
                                     ('720ef3bd-046e-4038-9af9-d4f57d19ab97'), /*MailTemplate DC*/
                                     ('bf506580-60c3-4ec2-8064-b7d5c3250ee2'), /*MailTemplate MM4*/
                                     ('db23e063-6c2a-42fc-8717-13f409e9471c'), /*MailTemplate VP3*/
                                     ('2365e9ab-be57-431e-a684-ad4414288c85'), /*Wizard - general*/
                                     ('00d6ae70-25b2-4309-a550-a80611edd9ca'), /*Approval workflow - general*/
                                     ('e1d72ea5-0c92-4b7a-8d34-50aea214551d'), /*Approval Workflow*/
                                     ('7d2afe70-41f9-48d0-b77e-505b78276288'), /*Ingest Workflow*/
                                     ('af793035-e640-41c1-8ac8-b7fc82a89ff0'), /*Config CCC*/
                                     ('34525287-c901-43b3-9f74-690b80401a69'), /*Product Urls CCC*/
                                     ('ed592e05-df20-4bd5-af08-eb03d4224888'), /*Config OC*/
                                     ('4709dc11-113d-475b-a8fc-325162e07930'), /*Product Urls OC*/
                                     ('5008b64b-4ce9-464f-9e4b-331780661dbd'), /*Video Portal*/
                                     ('96742e6e-546e-44ad-a893-807ae20cf2c2'), /*Default previews*/
                                     ('e708fc6c-cf77-408f-9ff8-3dfbeefde818'), /*Default previews*/
                                     ('2949707f-ca66-4d66-b57a-cb8c4aee69b0'), /*Default previews*/
                                     ('b3ea7051-307e-48ef-84f8-63256392d582'), /*Default previews*/
                                     ('8f3fd490-d437-446d-a2cf-3513b67df2a3'), /*Default previews*/
                                     ('8244c6dc-d1e2-41b9-b2d7-e668b13bbfd8'), /*Meta tags*/
                                     ('b52a269a-2796-4ed3-9f82-11b1a6683d4f'), /*Layoutfolder OfficeConnector*/
                                     ('3e51aba0-8050-418e-a371-5b99c87edafc'), /*Reklame Video*/
                                     ('c2571fdd-e110-46c5-b150-c4610868db67'), /*UserFields*/
                                     ('4df58509-e91c-4613-933d-45b226a11538'), /*Virtuel folder*/
                                     ('bf29056f-2e56-4a2c-9624-f741595aee46'), /*WebTV Config*/
                                     ('19e8579b-a25e-49cd-9691-6eab908af3f9'), /*YouTube*/
                                     ('f17d917a-a027-42d8-a489-547da4242fb5'), /*Labels*/
                                     ('4a99d3c8-575b-4390-b814-3d48bf60b09d'), /*MailLabels*/
                                     ('c562d958-a7ee-48eb-8f76-1a58fbf063dc'), /*MediaPortal Config*/
                                     ('5ed1a2d5-ce23-4996-884d-63fd44d0b62c'), /*Podcast*/
                                     ('2bf142a2-0c6e-4f18-a1dd-a7015294577d'), /*Rating*/
                                     ('2bba3ef2-4fc9-463c-a129-301ee08281a3'), /*Reklamer*/
                                     ('9ec20501-ce4e-4ad1-9c47-ccad794a743b'), /*Relateret Materiale*/
                                     ('6e7d857d-4094-43a9-b535-ac9696c75b00'), /*Topbar links*/
                                     ('6357cb96-9405-460f-ad65-8134fe017eba'), /*DFS Default previews*/
                                     ('9b980d53-8977-4e0b-9379-c4b988b668bf'), /*Episerver Crop*/
                                     ('8e04b0d0-a657-4d1d-bcfb-5059707462db'), /*AI Config*/
                                     ('2806afcf-1345-4213-a762-16a812c3ffee'), /*Copyright Notification*/
                                     ('928e748e-1956-438d-81a5-6c64d838afc3'), /*MailTemplate*/
                                     ('b088b01b-0b3b-4644-be69-f9d6625a12c1'), /*Presets*/
                                     ('09e1b967-80b2-4e73-86b2-fd5ffb8b333f'), /*Presets*/
                                     ('750847da-c10a-4022-b7ef-6022732e02f9'); /*Download request*/


EXEC dbo.DeleteProduct @ProductGuid = 'f77a0b88-f80a-45ce-a5b9-65b6e7817fbe';/* VP3 */
EXEC dbo.DeleteProduct @ProductGuid = 'f10abf14-6fb1-4515-a16a-0c6c02376989';/* MM4 */
EXEC dbo.DeleteProduct @ProductGuid = '726d5f54-c5ff-4f78-b931-167daaae389b';/* OC */
EXEC dbo.DeleteProduct @ProductGuid = '2350f493-d4ab-48ae-ac07-562242104035';/* Digizuite™ Adobe Creative Cloud Connector */
EXEC dbo.DeleteProduct @ProductGuid = '3206289a-5fbf-4656-b33e-9b3e0007d839';/* Episerver */
EXEC dbo.DeleteProduct @ProductGuid = 'AC045BF0-C538-4397-BC13-EF6A61DF6A82';/* Digizuite™ DAM for Sitecore */

INSERT INTO @metafieldGroupsToDelete
SELECT guid
FROM @metafieldGroupGuids
WHERE guid IN (SELECT ItemGuid FROM dbo.item);

WHILE EXISTS (SELECT * FROM @metafieldGroupsToDelete)
    BEGIN;
    SELECT TOP 1 @currentGuid = guid FROM @metafieldGroupsToDelete;
    DELETE FROM @metafieldGroupsToDelete WHERE guid = @currentGuid;

    SET @currentGuidString = @currentGuid;
    RaisError(N'Deleting metafield group %s', 0, 1, @currentGuidString) WITH NOWAIT;
    EXEC dbo.DeleteMetafieldGroup @itemGuid = @currentGuid;
    END;