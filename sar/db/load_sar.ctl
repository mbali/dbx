load data
infile *
into table sar_measurements
fields terminated by "|"
(
  system_name char,
  measurement_time date "YYYY.MM.DD HH24:MI:SS",
  unit_type char,
  unit_name char,
  measurement_code char,
  measurement_value decimal external
)

