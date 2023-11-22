from __future__ import annotations
import argparse
import json
import logging
import apache_beam.io.gcp.pubsublite as psub_lite
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions

# Defines the BigQuery schema for the output table.
schema = 'trip_id:INTEGER,vendor_id:INTEGER,trip_distance:FLOAT,fare_amount:STRING,store_and_fwd_flag:STRING'


class ModifyDataForBQ(beam.DoFn):
    def process(self, pubsub_message, *args, **kwargs):
        # attributes = dict(pubsub_message.attributes)
        obj = json.loads(pubsub_message.message.data.decode("utf-8"))
        yield obj


def run(
        subscription_id: str,
        dataset: str,
        table: str,
        beam_args: list[str] = None,
) -> None:
    options = PipelineOptions(beam_args, save_main_session=True, streaming=True, sdk_location="container")

    table = '{}.{}'.format(dataset, table)

    p = beam.Pipeline(options=options)

    pubsub_pipeline = (
            p
            | 'Read from pubsub lite topic' >> psub_lite.ReadFromPubSubLite(subscription_path=subscription_id)
            | 'Print Message' >> beam.ParDo(ModifyDataForBQ())
            | 'Write Record to BigQuery' >> beam.io.WriteToBigQuery(table=table, schema=schema,
                                                                    write_disposition=beam.io.BigQueryDisposition
                                                                    .WRITE_APPEND,
                                                                    create_disposition=beam.io.BigQueryDisposition
                                                                    .CREATE_IF_NEEDED, )
    )

    result = p.run()
    result.wait_until_finish()


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--subscription_id",
        type=str,
        help="Region of Pub/Sub Lite subscription.",
        default=None
    )
    parser.add_argument(
        "--dataset",
        type=str,
        help="BigQuery Dataset name.",
        default=None
    )
    parser.add_argument(
        "--table",
        type=str,
        help="BigQuery destination table name.",
        default=None
    )
    args, beam_args = parser.parse_known_args()

    run(
        subscription_id=args.subscription_id,
        dataset=args.dataset,
        table=args.table,
        beam_args=beam_args,
    )