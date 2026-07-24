/*==============================================================*/
/* DBMS name:      MySQL 5.0                                    */
/* Created on:     2026/7/24 9:16:09                            */
/*==============================================================*/


drop table if exists analysis_task;

drop table if exists dataset;

drop table if exists sequence;

drop table if exists species;

drop table if exists user;

/*==============================================================*/
/* Table: analysis_task                                         */
/*==============================================================*/
create table analysis_task
(
   tid                  int not null,
   uid                  int,
   did                  int,
   tuid                 int,
   tdid                 int,
   ttype                varchar(20),
   tstatus              varchar(20),
   result_path          varchar(20),
   error_msg            text,
   started_at           datetime,
   completed_at         datetime,
   created_at           datetime,
   primary key (tid)
);

/*==============================================================*/
/* Table: dataset                                               */
/*==============================================================*/
create table dataset
(
   did                  int not null,
   uid                  int,
   duid                 int,
   dname                varchar(50),
   source               varchar(10),
   ddescription         text,
   dstatus              varchar(10),
   primary key (did)
);

/*==============================================================*/
/* Table: sequence                                              */
/*==============================================================*/
create table sequence
(
   seid                 int not null,
   sid                  int,
   uid                  int,
   did                  int,
   seuid                int,
   sedid                int,
   sesid                int,
   accession            varchar(100),
   sename               varchar(50),
   file_path            varchar(50),
   se_length            int,
   ssource              varchar(10),
   primary key (seid)
);

/*==============================================================*/
/* Table: species                                               */
/*==============================================================*/
create table species
(
   sid                  int not null,
   uid                  int,
   suid                 int,
   sname                varchar(50),
   taxonomy_id          varchar(50),
   sdescription         text,
   primary key (sid)
);

/*==============================================================*/
/* Table: user                                                  */
/*==============================================================*/
create table user
(
   uid                  int not null,
   uname                varchar(20),
   upassword            varchar(60),
   nickname             varchar(20),
   role                 varchar(10),
   email                varchar(30),
   primary key (uid)
);

alter table analysis_task add constraint FK_Relationship_4 foreign key (uid)
      references user (uid) on delete restrict on update restrict;

alter table analysis_task add constraint FK_Relationship_6 foreign key (did)
      references dataset (did) on delete restrict on update restrict;

alter table dataset add constraint FK_Relationship_2 foreign key (uid)
      references user (uid) on delete restrict on update restrict;

alter table sequence add constraint FK_Relationship_3 foreign key (uid)
      references user (uid) on delete restrict on update restrict;

alter table sequence add constraint FK_Relationship_5 foreign key (did)
      references dataset (did) on delete restrict on update restrict;

alter table sequence add constraint FK_Relationship_7 foreign key (sid)
      references species (sid) on delete restrict on update restrict;

alter table species add constraint FK_Relationship_1 foreign key (uid)
      references user (uid) on delete restrict on update restrict;

