The scaffolded migration drops the Name column and adds FullName, which would destroy every existing value
(EF cannot tell a rename from a drop plus add). Replace it with migrationBuilder.RenameColumn. Then test the
upgrade on a restored copy of production data or a fixture with representative rows and check the values
survive; only then deploy.
