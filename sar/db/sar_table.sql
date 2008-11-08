create table sar_measurements
(
  system_name varchar2(100) not null,
  measurement_time date not null,
  unit_type varchar2(20),
  unit_name varchar2(30),
  measurement_code varchar2(20),
  measurement_value   number(10,2) not null
);

comment on table sar_measurements is 'Table for storing SAR measurements';

comment on column sar_measurements.system_name is 'Name of system';
comment on column sar_measurements.measurement_time is 'Timestamp of measurement';
comment on column sar_measurements.unit_type is 'Type of unit (if needed)';
comment on column sar_measurements.unit_name is 'Name of unit (if needed)';
comment on column sar_measurements.measurement_code is 'Code of measured data';
comment on column sar_measurements.measurement_value is 'Measured value';
