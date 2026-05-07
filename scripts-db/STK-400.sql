CREATE TABLE StickerKing.equipment_fix_statuses (
  id int(11) NOT NULL AUTO_INCREMENT,
  name varchar(50) DEFAULT NULL,
  PRIMARY KEY (id)
)
ENGINE = INNODB,
CHARACTER SET utf8mb4,
COLLATE utf8mb4_general_ci;

CREATE TABLE StickerKing.equipment_fix_list (
  id int(11) NOT NULL AUTO_INCREMENT,
  equip_id varchar(255) DEFAULT NULL,
  equip_fix_id int(11) DEFAULT NULL,
  datecreate datetime DEFAULT NULL,
  comment varchar(255) DEFAULT NULL,
  PRIMARY KEY (id)
)
ENGINE = INNODB,
AUTO_INCREMENT = 5,
AVG_ROW_LENGTH = 8192,
CHARACTER SET utf8mb4,
COLLATE utf8mb4_general_ci;

CREATE TABLE StickerKing.person_workflow (
  id int(11) NOT NULL AUTO_INCREMENT,
  person_id varchar(255) DEFAULT NULL,
  status int(11) DEFAULT NULL,
  datecreate datetime DEFAULT NULL,
  PRIMARY KEY (id)
)
ENGINE = INNODB,
CHARACTER SET utf8mb4,
COLLATE utf8mb4_general_ci;