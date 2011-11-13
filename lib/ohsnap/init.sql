CREATE TABLE photo (
	id       INTEGER PRIMARY KEY,
	location BLOB NOT NULL
);
CREATE UNIQUE INDEX photo_location on photo(location);

CREATE TABLE tag (
	id   INTEGER PRIMARY KEY,
	name TEXT NOT NULL
);
CREATE UNIQUE INDEX tag_name on tag(name);

CREATE TABLE photo_tag (
	photo INTEGER NOT NULL,
	tag   INTEGER NOT NULL,
	FOREIGN KEY(photo) REFERENCES photo(id),
	FOREIGN KEY(tag) REFERENCES tag(id)
);
CREATE INDEX photo_tag_photo on photo_tag(photo);
CREATE INDEX photo_tag_tag on photo_tag(tag);

CREATE TABLE photo_representation (
	photo    INTEGER NOT NULL,
	original INTEGER NOT NULL, --used as bool for original/retouched
	type     INTEGER NOT NULL, --enum {0 => NEF RAW, 1 => JPG}
	height   INTEGER NOT NULL,
	width    INTEGER NOT NULL,
	FOREIGN KEY(photo) REFERENCES photo(id)
);
CREATE INDEX repr_photo_orig on photo_representation(photo, original);

CREATE TABLE exif_info (
	photo INTEGER NOT NULL,
	key   BLOB NOT NULL,
	value BLOB,
	FOREIGN KEY(photo) REFERENCES photo(id)
);
CREATE INDEX exif_photo on exif_info(photo);
CREATE INDEX exif_key_photo on exif_info(key, photo);
