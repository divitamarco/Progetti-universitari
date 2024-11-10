"""
Script sviluppato appositamente per la prima esercitazione di Big Data e machine learning
"""
from pyspark.context import SparkContext
from pyspark.sql.session import SparkSession
from pyspark.sql.functions import (count,
                                   asc,
                                   input_file_name,
                                   split,
                                   col,
                                   lit)
# nome della cartella principale dei file => "/<nome_cartella>/"
ROOT_DIR_DATASET: str = "YOUR ROOT DIR"
# path della cartella principale dei file => "hdfs://<path>/" + "*"
PATH_DIR_DATASET: str = "YOUR DATASET PATH" + "*"
# path di salvataggio dei risultati del codice
RESULT_DIR_DATASET: str = "YOUR RESULT PATH"

COORDINATES: str = "[(60,-135);(30,-90)]"

ORDER_TASK_1 = ['Anno', 'Stazione', 'Numero_misurazioni']
ORDER_TASK_2 = ['Coordinates', 'TMP', 'N_TMP']
ORDER_TASK_3 = ['Stazione', 'Velocita_vento', 'Occorrenze_velocita']

RESULT_CSV_NAME_T1: str ="r1_4"
RESULT_CSV_NAME_T2: str ="r2_4"
RESULT_CSV_NAME_T3: str ="r3_4"


sc = SparkContext.getOrCreate()
spark = SparkSession(sc)

df = spark.read.option("header", "true") \
    .option("recursiveFileLookup", "true") \
    .csv(PATH_DIR_DATASET) \
    .withColumn("Anno",            split( split( input_file_name(), ROOT_DIR_DATASET)[1], "/")[0] ) \
    .withColumn("Stazione", split( split( split( input_file_name(), ROOT_DIR_DATASET)[1], "/")[1], ".csv")[0])\
    .withColumn("Velocita_vento", split(col('WND'),",")[1])

df_task_2 = df.select("LATITUDE","LONGITUDE","TMP")\
             .where((df['LATITUDE'] >=30) & (df['LATITUDE'] <=60) &
                    (df['LONGITUDE'] >= -135) & (df['LONGITUDE'] <= -90))

# TASK 1
task_1_counts = df.groupBy("Stazione", "Anno").agg(count('*').alias('Numero_misurazioni'))
task_1_sorted=task_1_counts.sort('Numero_misurazioni', ascending = False)

# TASK 2
task_2_grouped = df_task_2.groupBy('TMP').agg(count('*').alias('N_TMP'))
task_2_filter=task_2_grouped.sort('N_TMP', ascending= False).limit(10).withColumn("Coordinates", lit(COORDINATES))

# TASK 3
task_3_counts = df.select("Stazione", "Velocita_vento").groupBy("Stazione", "Velocita_vento").agg(count('*').alias('Occorrenze_velocita'))
task_3_sorted = task_3_counts.sort('Occorrenze_velocita', ascending = False)
task_3_first_row = task_3_sorted.limit(1)


task_1_sorted.select(ORDER_TASK_1).write.options(header='True', delimiter=',', mode='overwrite').csv(RESULT_DIR_DATASET + "/" + RESULT_CSV_NAME_T1 )
task_2_filter.select(ORDER_TASK_2).write.options(header='True', delimiter=',', mode='overwrite').csv(RESULT_DIR_DATASET + "/" + RESULT_CSV_NAME_T2 )
task_3_first_row.select(ORDER_TASK_3).write.options(header='True', delimiter=',', mode='overwrite').csv(RESULT_DIR_DATASET + "/" + RESULT_CSV_NAME_T3 )
