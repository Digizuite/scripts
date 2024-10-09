-- Ensure that IgnoreSecurity is controlled completely based on the "No-security channel folders" setting on formats.
UPDATE Renditions
SET IgnoreSecurity = 0
WHERE IgnoreSecurity = 1;