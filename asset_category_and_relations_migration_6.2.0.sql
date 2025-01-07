IF NOT EXISTS (SELECT *
               FROM ConfigurationManagementService_ConfigurationLayers
               WHERE Name = 'KeyShot')
    RETURN;
    
IF EXISTS (SELECT *
           FROM ConfigurationManagementService_ConfigurationLayers
           WHERE Name = 'KeyShot' AND TemplateVersion = '6.2.0')
    RETURN;

DECLARE @rootId int = 1;
DECLARE @renderOutputGuid uniqueidentifier = '3e2851ad-5013-4ca3-9b4b-d37e22eafa02';
MERGE asset_category as target
USING (
SELECT N'Render Output' as name, @renderOutputGuid as guid, 0 as is_abstract, @rootId as parent_category_id, 0 as is_sealed
) AS source
ON target.guid = source.guid
WHEN NOT MATCHED BY TARGET THEN
INSERT (name, is_abstract, parent_category_id, is_sealed, is_locked, description, guid)
VALUES (name, is_abstract, parent_category_id, is_sealed, 0, N'', guid)
WHEN MATCHED THEN UPDATE SET target.name = source.name
;

DECLARE @renderOutputId int = (SELECT id FROM asset_category WHERE guid = @renderOutputGuid);

MERGE asset_category as target
USING (
SELECT N'Animation' as name, '4a3c3cfc-2797-4e04-b8e2-5dd433e68072' as guid, 0 as is_abstract, @renderOutputId as parent_category_id, 0 as is_sealed
UNION SELECT 'Backplate', '1e26425d-8f2d-4c27-aaec-dd3d6afe5e5b', 0, @rootId, 0
UNION SELECT 'CMF', '953bd772-a3bf-4a95-af2e-31a68044d46f', 0, @renderOutputId, 0
UNION SELECT 'Configurator', '71ec5f02-1915-41f9-b166-3a4226d5e38b', 0, @renderOutputId, 0
UNION SELECT  'Environment', 'bbe9ab41-87a7-4769-970d-25610a750846', 0, @rootId, 0
UNION SELECT 'Geometry', '395eb7e0-fab3-46a3-91a1-a0eb6f9bc805', 0, @rootId, 0
UNION SELECT 'Material', 'e923c56f-6c0d-4914-a269-3d22ec733c70', 0, @rootId, 0
UNION SELECT 'Model', 'db7b0385-2d33-444a-953c-7e05b8e0b799', 0, @rootId, 0
UNION SELECT 'Render Layer', '89981c7f-c1b4-4de6-b29b-e2c955cb4e31', 0, @renderOutputId, 0
UNION SELECT 'Render Pass', '661e025d-dd15-4976-9c78-1d66020c9dea', 0, @renderOutputId, 0
UNION SELECT 'Scene', 'e69b166e-f854-46f6-b226-570d71c6b9a8', 0, @rootId, 0
UNION SELECT 'Still Image', '807cc7b7-0c7f-46f5-8d5d-bd9948d69503', 0, @renderOutputId, 0
UNION SELECT 'Texture', '352e6ba1-4170-4b39-913a-c85fff5c2b52', 0, @rootId, 0
) AS source
ON target.guid = source.guid
WHEN NOT MATCHED BY TARGET THEN
INSERT (name, is_abstract, parent_category_id, is_sealed, is_locked, description, guid)
VALUES (name, is_abstract, parent_category_id, is_sealed, 0, N'', guid)
WHEN MATCHED THEN UPDATE SET target.name = source.name
;


with a1 as (select assetid, item_id as itemid, SourceFilename, Extension
            from asset),
     keyshot_types as (select imv.itemid, icv.optionvalue
                       from item_metafield imf
                                inner join dbo.item i on imf.item_id = i.itemid
                                inner join dbo.item_metafield_label iml on imf.item_metafieldid = iml.item_metafieldid
                           and iml.languageid = (select top 1 languageid from dbo.language where enabled = 1)
                                inner join dbo.item_combo_value icv
                                           on iml.item_metafield_labelid = icv.item_metafield_labelid
                                inner join dbo.item_metafield_value imv
                                           on imv.item_combo_valueid = icv.item_combo_valueid
                       where i.ItemGuid = '2679ac62-8f06-42d3-b8be-19767e40ee31'),
     keyshot_render_types as (select imv.itemid, icv.optionvalue
                              from item_metafield imf
                                       inner join dbo.item i on imf.item_id = i.itemid
                                       inner join dbo.item_metafield_label iml
                                                  on imf.item_metafieldid = iml.item_metafieldid
                                                      and iml.languageid =
                                                          (select top 1 languageid from dbo.language where enabled = 1)
                                       inner join dbo.item_combo_value icv
                                                  on iml.item_metafield_labelid = icv.item_metafield_labelid
                                       inner join dbo.item_metafield_value imv
                                                  on imv.item_combo_valueid = icv.item_combo_valueid
                              where i.ItemGuid = 'fc5be89a-a6fa-4013-aa71-ba189e938649'),
     assets_enriched as (select a1.*,
                                (select optionvalue from keyshot_types kt where kt.itemid = a1.itemid)          as keyshot_type,
                                (select optionvalue
                                 from keyshot_render_types krt
                                 where krt.itemid = a1.itemid)                                                  as render_type
                         from a1),
     assets_new_category as (select ae.*,
                                    CASE
                                        WHEN keyshot_type = N'Backplates' THEN N'Backplate'
                                        WHEN keyshot_type = N'Colors' THEN N'Uncategorized'
                                        WHEN keyshot_type = N'Environments' THEN N'Environment'
                                        WHEN keyshot_type = N'Materials' THEN N'Material'
                                        WHEN keyshot_type = N'Models' THEN N'Model'
                                        WHEN keyshot_type = N'Render Output' THEN
                                            CASE
                                                WHEN render_type = N'Animation' THEN N'Animation'
                                                WHEN render_type = N'CMF' THEN N'CMF'
                                                WHEN render_type = N'Still Image' THEN
                                                    IIF((
                                                            (patindex('%_ao.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_ao.exr', lower(SourceFilename)) > 1)
                                                                or
                                                            (patindex('%_caustics.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_clown.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_depth.exr', lower(SourceFilename)) > 1)
                                                                or
                                                            (patindex('%_diffuse.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_gi.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_label.exr', lower(SourceFilename)) > 1)
                                                                or
                                                            (patindex('%_lighting.exr', lower(SourceFilename)) > 1)
                                                                or
                                                            (patindex('%_normals.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_raw.exr', lower(SourceFilename)) > 1)
                                                                or
                                                            (patindex('%_reflection.exr', lower(SourceFilename)) > 1)
                                                                or
                                                            (patindex('%_refraction.exr', lower(SourceFilename)) > 1)
                                                                or (patindex('%_shadow.exr', lower(SourceFilename)) > 1)
                                                            ), N'Render pass', N'Still Image')
                                                ELSE N'Render Output'
                                                END
                                        WHEN keyshot_type = N'Scenes' THEN N'Scene'
                                        WHEN keyshot_type = N'Textures' THEN N'Texture'
                                        ELSE null
                                        END as new_category
                             from assets_enriched ae),
     assets_for_update as (select assetid, (select id from asset_category where name = new_category) as category_id
                           from assets_new_category
                           where new_category is not null)
update a
set asset_category_id = category_id
from assets_for_update afu
         inner join asset a on afu.assetid = a.assetid

MERGE asset_relation_types as target
USING (
SELECT '03e0d7cc-2cb5-40ff-b8a2-adbe2bc3fbaa' as guid, N'Scenes-Materials' as name, N'' as description, 0 as is_locked, 4 as multiplicity, 0 as system_assignable_only
UNION SELECT '122aeb77-bfa8-40e5-a71f-02186f9c81b5', N'Scenes-Environments', N'',0,4,0
UNION SELECT '51e20c13-9912-4dd8-895d-29ca13b2af9e', N'Scenes-Backplates', N'',0,4,0
UNION SELECT '7b8e7dd1-c501-426f-ac4f-278746ca320f', N'Scenes-Models', N'',0,4,0
UNION SELECT '85e4c18b-075a-4ca5-88d5-f2ad83cf6e0b', N'Scenes-Geometry', N'',0,3,0
UNION SELECT '1bc81b90-47ea-4f0f-ad40-96a93e3b2c1b', N'Scenes-Textures', N'',0,4,0
UNION SELECT '238feddf-d6c2-4956-bca2-aa7bf5eb7b6b', N'Scene-Render Outputs',N'',0,2,0
UNION SELECT 'f5cea732-44f9-4f10-ba9c-1e9814eb741a', N'Materials-Textures', N'',0,4,0
UNION SELECT 'cb6409ba-66ad-449c-8278-e8339d6d75ee', N'Environments-Backplates', N'',0,4,0
UNION SELECT '4927cf8d-ae8c-4988-9caa-79566258f41b', N'Models-Materials', N'',0,4,0
UNION SELECT '23d8d7cf-c99e-4f2c-9264-a721d4b89de1',N'Models-Environments', N'',0,4,0
UNION SELECT '635463d9-5418-439a-9b6b-58aa9853e144', N'Models-Backplates', N'',0,4,0
UNION SELECT 'e7a86097-3da1-4c58-97c5-c88f1c4a4fb9', N'Models-Textures', N'',0,4,0
UNION SELECT '6a6d8889-ab3a-489d-b4d4-6c5cdea50a2e', N'Still Image-Render Passes', N'',0,2,0
UNION SELECT '93a924f7-aa90-4164-a710-f37018cc086a', N'Still Image-Render Layers', N'',0,2,0
UNION SELECT '3d76b51b-c8a1-4ec5-a567-fcebd063c0cc', N'Configurator-Still Images', N'',0,2,0
UNION SELECT 'f8be0885-1cb5-43a2-8a3a-be062e1bdde4', N'Environment-Environment',N'',0,1,0
UNION SELECT '75f737ae-1a2c-4dc5-83c6-8e70c2f139b7', N'Environment-Textures', N'',0,2,0
) AS source
ON target.guid = source.guid
WHEN NOT MATCHED BY TARGET THEN
INSERT (guid, name, description, is_locked, multiplicity, system_assignable_only)
VALUES (guid, name, description, is_locked, multiplicity, system_assignable_only)
;


with mappings as (select 'e69b166e-f854-46f6-b226-570d71c6b9a8' as from_cat_guid,
                         'e923c56f-6c0d-4914-a269-3d22ec733c70' as to_cat_guid,
                         '03e0d7cc-2cb5-40ff-b8a2-adbe2bc3fbaa' as rel_type_guid
                  union
                  select 'e69b166e-f854-46f6-b226-570d71c6b9a8',
                         'bbe9ab41-87a7-4769-970d-25610a750846',
                         '122aeb77-bfa8-40e5-a71f-02186f9c81b5'
                  union
                  select 'e69b166e-f854-46f6-b226-570d71c6b9a8',
                         '1e26425d-8f2d-4c27-aaec-dd3d6afe5e5b',
                         '51e20c13-9912-4dd8-895d-29ca13b2af9e'
                  union
                  select 'e69b166e-f854-46f6-b226-570d71c6b9a8',
                         'db7b0385-2d33-444a-953c-7e05b8e0b799',
                         '7b8e7dd1-c501-426f-ac4f-278746ca320f'
                  union
                  select 'e69b166e-f854-46f6-b226-570d71c6b9a8',
                         '395eb7e0-fab3-46a3-91a1-a0eb6f9bc805',
                         '85e4c18b-075a-4ca5-88d5-f2ad83cf6e0b'
                  union
                  select 'e69b166e-f854-46f6-b226-570d71c6b9a8',
                         '352e6ba1-4170-4b39-913a-c85fff5c2b52',
                         '1bc81b90-47ea-4f0f-ad40-96a93e3b2c1b'
                  union
                  select 'e69b166e-f854-46f6-b226-570d71c6b9a8',
                         '3e2851ad-5013-4ca3-9b4b-d37e22eafa02',
                         '238feddf-d6c2-4956-bca2-aa7bf5eb7b6b'
                  union
                  select 'e923c56f-6c0d-4914-a269-3d22ec733c70',
                         '352e6ba1-4170-4b39-913a-c85fff5c2b52',
                         'f5cea732-44f9-4f10-ba9c-1e9814eb741a'
                  union
                  select 'bbe9ab41-87a7-4769-970d-25610a750846',
                         '1e26425d-8f2d-4c27-aaec-dd3d6afe5e5b',
                         'cb6409ba-66ad-449c-8278-e8339d6d75ee'
                  union
                  select 'db7b0385-2d33-444a-953c-7e05b8e0b799',
                         'e923c56f-6c0d-4914-a269-3d22ec733c70',
                         '4927cf8d-ae8c-4988-9caa-79566258f41b'
                  union
                  select 'db7b0385-2d33-444a-953c-7e05b8e0b799',
                         'bbe9ab41-87a7-4769-970d-25610a750846',
                         '23d8d7cf-c99e-4f2c-9264-a721d4b89de1'
                  union
                  select 'db7b0385-2d33-444a-953c-7e05b8e0b799',
                         '1e26425d-8f2d-4c27-aaec-dd3d6afe5e5b',
                         '635463d9-5418-439a-9b6b-58aa9853e144'
                  union
                  select 'db7b0385-2d33-444a-953c-7e05b8e0b799',
                         '352e6ba1-4170-4b39-913a-c85fff5c2b52',
                         'e7a86097-3da1-4c58-97c5-c88f1c4a4fb9'
                  union
                  select '807cc7b7-0c7f-46f5-8d5d-bd9948d69503',
                         '661e025d-dd15-4976-9c78-1d66020c9dea',
                         '6a6d8889-ab3a-489d-b4d4-6c5cdea50a2e'
                  union
                  select '807cc7b7-0c7f-46f5-8d5d-bd9948d69503',
                         '89981c7f-c1b4-4de6-b29b-e2c955cb4e31',
                         '93a924f7-aa90-4164-a710-f37018cc086a'
                  union
                  select '71ec5f02-1915-41f9-b166-3a4226d5e38b',
                         '807cc7b7-0c7f-46f5-8d5d-bd9948d69503',
                         '3d76b51b-c8a1-4ec5-a567-fcebd063c0cc'
                  union
                  select 'bbe9ab41-87a7-4769-970d-25610a750846',
                         'bbe9ab41-87a7-4769-970d-25610a750846',
                         'f8be0885-1cb5-43a2-8a3a-be062e1bdde4'
                  union
                  select 'bbe9ab41-87a7-4769-970d-25610a750846',
                         '352e6ba1-4170-4b39-913a-c85fff5c2b52',
                         '75f737ae-1a2c-4dc5-83c6-8e70c2f139b7'),
     base_q as (select src_asset.assetid                 as src_assetid,
                       src_ac.guid                       as src_guid,
                       dst_asset.assetid                 as dst_assetid,
                       dst_ac.guid                       as dst_guid,
                       (select top 1 rel_type_guid
                        from mappings
                        where from_cat_guid = src_ac.guid
                          and to_cat_guid = dst_ac.guid) as rel_type_guid
                from item_metafield_value imv
                         inner join item_metafield_label iml
                                    on imv.item_metafield_labelid = iml.item_metafield_labelid
                                        and iml.languageid =
                                            (select top 1 languageid from dbo.language where enabled = 1)
                         inner join asset src_asset on imv.itemid = src_asset.item_id
                         inner join asset_category src_ac on src_asset.asset_category_id = src_ac.id
                         inner join asset dst_asset on imv.ref_itemid = dst_asset.item_id
                         inner join asset_category dst_ac on dst_asset.asset_category_id = dst_ac.id
                         inner join item_metafield imf on iml.item_metafieldid = imf.item_metafieldid
                         inner join item on imf.item_id = item.itemid and
                                            item.ItemGuid = '3e5a239f-c172-4754-8faf-d485616a8552'),
     enriched_q as (select src_assetid,
                           dst_assetid,
                           (select id from asset_relation_types where guid = rel_type_guid) as relation_type_id,
                           (select multiplicity
                            from asset_relation_types
                            where guid = rel_type_guid)                                     as multiplicity
                    from base_q
                    where rel_type_guid is not null),
     one_one_vio_src as (select src_assetid, relation_type_id, count(*) as v_cnt
                         from enriched_q
                         where multiplicity = 1
                         group by src_assetid, relation_type_id
                         having count(*) > 1),
     one_one_vio_dst as (select dst_assetid, relation_type_id, count(*) as v_cnt
                         from enriched_q
                         where multiplicity = 1
                         group by dst_assetid, relation_type_id
                         having count(*) > 1),
     one_many_vio as (select dst_assetid, relation_type_id, count(*) as v_cnt
                      from enriched_q
                      where multiplicity = 2
                      group by dst_assetid, relation_type_id
                      having count(*) > 1),
     many_one_vio as (select src_assetid, relation_type_id, count(*) as v_cnt
                      from enriched_q
                      where multiplicity = 3
                      group by src_assetid, relation_type_id
                      having count(*) > 1),
     filtered as (select *
                  from enriched_q q
                  where not exists (select *
                                    from asset_relations ar
                                    where ar.asset_relation_type_id = q.relation_type_id
                                      and ar.primary_asset_id = q.src_assetid
                                      and ar.secondary_asset_id = q.dst_assetid)
                    and not exists (select *
                                    from one_one_vio_src f1
                                    where q.src_assetid = f1.src_assetid
                                      and q.relation_type_id = f1.relation_type_id)
                    and not exists (select *
                                    from one_one_vio_dst f2
                                    where q.dst_assetid = f2.dst_assetid
                                      and q.relation_type_id = f2.relation_type_id)
                    and not exists (select *
                                    from one_many_vio f3
                                    where q.dst_assetid = f3.dst_assetid
                                     and q.relation_type_id = f3.relation_type_id)
                    and not exists (select *
                                    from many_one_vio f4
                                    where q.src_assetid = f4.src_assetid
                                      and q.relation_type_id = f4.relation_type_id)
                  )
insert into asset_relations (asset_relation_type_id, primary_asset_id, secondary_asset_id, allowed_multiplicity)
select relation_type_id, src_assetid, dst_assetid, multiplicity
from filtered

