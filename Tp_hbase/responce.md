## Responces of questions : 
1)The row key is crucial because it serves as HBase's only primary index, enabling instant, direct access to specific records without scanning the entire table.

2) Unlike a static CSV file in HDFS that requires full sequential scans for batch processing, HBase enables real-time, low-latency random reads and writes.

3) Sequential ordered keys allow efficient range scans but risk overloading a single region server (hotspotting), whereas hashed keys distribute write traffic evenly but prevent efficient range queries.

## Discuss the difference between a global analytical query and targeted access:
A global analytical query (OLAP) scans large volumes of data to compute aggregate insights with high throughput but higher latency, whereas targeted access (OLTP) uses a specific row key to instantly retrieve or update individual records in milliseconds
