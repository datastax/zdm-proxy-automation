#!/bin/bash

INSERT_DML="INSERT INTO test_keyspace.test_table (id, window_day, read_minute, value)"

function get_host_info() {
    host_var_name=$1

    echo "Getting info for entry '$host_var_name'"
    while [ ! -f ${HOSTS_FILE} ]
    do
        echo "Waitng for $HOSTS_FILE to be created, trying again in 20s"
        sleep 20
    done

    get_host_info_result=$(grep "$host_var_name" $HOSTS_FILE)
    while [ "$get_host_info_result" = "" ]
    do
        echo "no '$host_var_name' entry found in hostsfile, trying again in 20s"
        sleep 20
        get_host_info_result=$(grep "$host_var_name" $HOSTS_FILE)
    done
}

function test_conn() {
    cqlsh $1 -e 'quit;'
    while [ $? -ne 0 ]
    do echo "cqlsh not ready on $1"
        sleep 30
        cqlsh $1 -e 'quit;'
    done
}

function get_window_day() {
    date +%Y%m%d
}

function get_read_minute() {
    date +%H%M
}

function execute_cql_statement() {
    # 1 - executing host
    # 2 - CQL statement
    cqlsh $1 -e "$2" 2>/dev/null
}

function create_schema_origin() {
    create_schema "$cassandra_origin_host" "datacenter1"
}

function create_schema_target() {
    create_schema "$cassandra_target_host" "replication_factor"
}

function create_schema() {
    # 1 - executing host
    # 2 - datacenter replication
    local cqlsh_statement=$(cat << HEREDOC_CQL
CREATE KEYSPACE IF NOT EXISTS test_keyspace
    WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy', '$2' : 1 };
CREATE TABLE IF NOT EXISTS test_keyspace.test_table(
    id int,
    window_day int,
    read_minute int,
    value text,
    PRIMARY KEY ((id, window_day), read_minute)
        );
HEREDOC_CQL
)
    execute_cql_statement $1 "$cqlsh_statement"
}

function insert_historical_data() {
    # 1 - executing host
    local window_day=$(get_window_day)
    local cqlsh_statement=$(cat << HEREDOC_CQL
$INSERT_DML VALUES (1, $window_day, 0000, '$RANDOM');
$INSERT_DML VALUES (1, $window_day, 0001, '$RANDOM');
$INSERT_DML VALUES (1, $window_day, 0002, '$RANDOM');
$INSERT_DML VALUES (1, $window_day, 0003, '$RANDOM');
$INSERT_DML VALUES (1, $window_day, 0004, '$RANDOM');
$INSERT_DML VALUES (1, $window_day, 0005, '$RANDOM');
HEREDOC_CQL
)
    execute_cql_statement $1 "$cqlsh_statement"
}

function insert_live_data() {
    # 1 - executing host
    local window_day=$(get_window_day)
    local read_minute=$(get_read_minute)
    local data_value=$RANDOM
    echo "Inserting data: window_day=$window_day read_minute=$read_minute value=$data_value"
    execute_cql_statement $1 "$INSERT_DML VALUES (1, $window_day, $read_minute, '$data_value');"
}

function select_data() {
    # 1 - executing host
    local window_day=$(get_window_day)
    echo "Reading data from $1: window_day=$window_day"
    execute_cql_statement $1 "SELECT * FROM test_keyspace.test_table WHERE id=1 AND window_day=$window_day;"
}

for var_name in "CASSANDRA_ORIGIN" "CASSANDRA_TARGET" "PROXY_1"
do
    get_host_info_result=""
    get_host_info $var_name

    host_var_name="$(tr '[:upper:]' '[:lower:]' <<<$var_name)_host"

    eval $host_var_name=$(cut -d':' -f2 <<<"$get_host_info_result")
done

echo "Testing cqlsh to $proxy_1_host"
test_conn $proxy_1_host

echo "Creating schema on $cassandra_origin_host"
create_schema_origin

echo "Creating schema on $cassandra_target_host"
create_schema_target

echo "Adding historical data to $cassandra_origin_host"
insert_historical_data $cassandra_origin_host
select_data $cassandra_origin_host

sleep 10

echo
echo
echo "===== Running proxy test ====="
while true
do
    echo
    insert_live_data $proxy_1_host
    select_data $proxy_1_host
    select_data $cassandra_origin_host
    select_data $cassandra_target_host
    echo "=============================="
    sleep 60
done

echo "Ready"
tail -F /dev/null # keeps container running