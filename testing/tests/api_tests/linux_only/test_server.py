import json
import warnings


import pytest
from jsonschema import validate
from jsonschema.exceptions import ValidationError
import requests
from requests.auth import HTTPBasicAuth
import urllib3
import os

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

current_script_path = os.path.abspath(__file__)
current_script_dir = os.path.dirname(current_script_path)


def convertJsonFileToString(file_path):
    with open(file_path, 'r') as file:
        return file.read()

@pytest.fixture(autouse=True)
def suppress_insecure_request_warning():
    warnings.simplefilter("ignore", urllib3.exceptions.InsecureRequestWarning)

def test_elastic_root():
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')
    url = f"https://{es_host}:{es_port}"
    response = make_request(url)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    body = response.json()

    assert body['name'] == 'es01', f"Expected 'es01', got {body['name']}"
    assert body['cluster_name']=='loggingmadeeasy-es', f"Expected 'loggingmadeeasy-es', got {body['cluster_name']}"
    assert body['version']['number'] == '8.11.1', f"Expected '8.11.1', got {body['version']['number']}"
    assert body['version']['build_flavor'] == 'default', f"Expected 'default', got {body['version']['build_flavor']}"
    assert body['version']['build_type'] == 'docker', f"Expected 'docker', got {body['version']['build_type']}"
    assert body['version']['lucene_version'] == '9.8.0', f"Expected '9.8.0', got {body['version']['lucene_version']}"
    assert body['version']['minimum_wire_compatibility_version'] == '7.17.0', f"Expected '7.17.0', got {body['version']['minimum_wire_compatibility_version']}"
    assert body['version']['minimum_index_compatibility_version'] == '7.0.0', f"Expected '7.0.0', got {body['version']['minimum_index_compatibility_version']}"

    #Validating JSON Response schema
    schema = load_json_schema(f"{current_script_dir}/schemas/es_root.json")
    try:
        validate(instance=response.text, schema=schema)
        print("JSON data is valid.")
    except ValidationError as ve:
        print("JSON data is invalid.")
        print(ve)

def test_elastic_indices():
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')
    url = f"https://{es_host}:{es_port}/_cat/indices/"
    response = make_request(url)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert 'green open .internal.alerts-observability.logs.alerts-default' in response.text
    assert 'green open .internal.alerts-observability.uptime.alerts-default' in response.text
    assert 'green open .internal.alerts-ml.anomaly-detection.alerts-default' in response.text
    assert 'green open .internal.alerts-observability.slo.alerts-default' in response.text
    assert 'green open .internal.alerts-observability.apm.alerts-default' in response.text
    assert 'green open .internal.alerts-observability.metrics.alerts-default' in response.text
    assert 'green open .kibana-observability-ai-assistant-conversations' in response.text
    assert 'green open winlogbeat' in response.text
    assert 'green open .internal.alerts-observability.threshold.alerts-default' in response.text
    assert 'green open .kibana-observability-ai-assistant-kb' in response.text
    assert 'green open .internal.alerts-security.alerts-default' in response.text
    assert 'green open .internal.alerts-stack.alerts-default' in response.text

def test_elastic_mapping():
    # This test currently works for full installation. For Partial installation (only Ls1), the static mappings file will need to be changed.
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')
    url = f"https://{es_host}:{es_port}/winlogbeat-000001/_mapping"
    response = make_request(url)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"

    response_data = json.loads(response.text)
    static_mapping = json.load(open(f"{current_script_dir}/test_data/mapping_response.json"))

    # Dumping Actual Response Json into file for comparison if test fails.
    datas = json.dump(response_data, open(f"{current_script_dir}/test_data/mapping_response_actual.json", 'w'), indent = 4)

    assert static_mapping == response_data, "Mappings Json did not match Expected"

def test_winlogbeat_settings():
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')

    url = f"https://{es_host}:{es_port}/winlogbeat-*/_settings"
    response = make_request(url)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    body = response.json()

    #Getting the value of Root Key
    for key in body:
        rootKey=key

    assert body[rootKey]["settings"]["index"]["lifecycle"]["name"]=="lme_ilm_policy" , f'Expected "lme_ilm_policy", got {body[rootKey]["settings"]["index"]["lifecycle"]["name"]}'
    assert body[rootKey]["settings"]["index"]["lifecycle"]["rollover_alias"]=="winlogbeat-alias", f'Expected "winlogbeat-alias", got {body[rootKey]["settings"]["index"]["lifecycle"]["rollover_alias"]}'

    assert "creation_date" in body[rootKey]["settings"]["index"], "Expected creation_date property, not found"
    assert "number_of_replicas" in body[rootKey]["settings"]["index"],"Expected number_of_replicas property, not found"
    assert "uuid" in body[rootKey]["settings"]["index"] , "Expected uuid property, not found"
    assert "created" in body[rootKey]["settings"]["index"]["version"] , "Expected created property, not found"

    dataFields=[
            "message",
            "tags",
            "agent.ephemeral_id",
            "agent.id",
            "agent.name",
            "agent.type",
            "agent.version",
            "as.organization.name",
            "client.address",
            "client.as.organization.name",
            "client.domain",
            "client.geo.city_name",
            "client.geo.continent_name",
            "client.geo.country_iso_code",
            "client.geo.country_name",
            "client.geo.name",
            "client.geo.region_iso_code",
            "client.geo.region_name",
            "client.mac",
            "client.registered_domain",
            "client.top_level_domain",
            "client.user.domain",
            "client.user.email",
            "client.user.full_name",
            "client.user.group.domain",
            "client.user.group.id",
            "client.user.group.name",
            "client.user.hash",
            "client.user.id",
            "client.user.name",
            "cloud.account.id",
            "cloud.availability_zone",
            "cloud.instance.id",
            "cloud.instance.name",
            "cloud.machine.type",
            "cloud.provider",
            "cloud.region",
            "container.id",
            "container.image.name",
            "container.image.tag",
            "container.name",
            "container.runtime",
            "destination.address",
            "destination.as.organization.name",
            "destination.domain",
            "destination.geo.city_name",
            "destination.geo.continent_name",
            "destination.geo.country_iso_code",
            "destination.geo.country_name",
            "destination.geo.name",
            "destination.geo.region_iso_code",
            "destination.geo.region_name",
            "destination.mac",
            "destination.registered_domain",
            "destination.top_level_domain",
            "destination.user.domain",
            "destination.user.email",
            "destination.user.full_name",
            "destination.user.group.domain",
            "destination.user.group.id",
            "destination.user.group.name",
            "destination.user.hash",
            "destination.user.id",
            "destination.user.name",
            "dns.answers.class",
            "dns.answers.data",
            "dns.answers.name",
            "dns.answers.type",
            "dns.header_flags",
            "dns.id",
            "dns.op_code",
            "dns.question.class",
            "dns.question.name",
            "dns.question.registered_domain",
            "dns.question.subdomain",
            "dns.question.top_level_domain",
            "dns.question.type",
            "dns.response_code",
            "dns.type",
            "ecs.version",
            "error.code",
            "error.id",
            "error.message",
            "error.stack_trace",
            "error.type",
            "event.action",
            "event.category",
            "event.code",
            "event.dataset",
            "event.hash",
            "event.id",
            "event.kind",
            "event.module",
            "event.outcome",
            "event.provider",
            "event.timezone",
            "event.type",
            "file.device",
            "file.directory",
            "file.extension",
            "file.gid",
            "file.group",
            "file.hash.md5",
            "file.hash.sha1",
            "file.hash.sha256",
            "file.hash.sha512",
            "file.inode",
            "file.mode",
            "file.name",
            "file.owner",
            "file.path",
            "file.target_path",
            "file.type",
            "file.uid",
            "geo.city_name",
            "geo.continent_name",
            "geo.country_iso_code",
            "geo.country_name",
            "geo.name",
            "geo.region_iso_code",
            "geo.region_name",
            "group.domain",
            "group.id",
            "group.name",
            "hash.md5",
            "hash.sha1",
            "hash.sha256",
            "hash.sha512",
            "host.architecture",
            "host.geo.city_name",
            "host.geo.continent_name",
            "host.geo.country_iso_code",
            "host.geo.country_name",
            "host.geo.name",
            "host.geo.region_iso_code",
            "host.geo.region_name",
            "host.hostname",
            "host.id",
            "host.mac",
            "host.name",
            "host.os.family",
            "host.os.full",
            "host.os.kernel",
            "host.os.name",
            "host.os.platform",
            "host.os.version",
            "host.type",
            "host.user.domain",
            "host.user.email",
            "host.user.full_name",
            "host.user.group.domain",
            "host.user.group.id",
            "host.user.group.name",
            "host.user.hash",
            "host.user.id",
            "host.user.name",
            "http.request.body.content",
            "http.request.method",
            "http.request.referrer",
            "http.response.body.content",
            "http.version",
            "log.level",
            "log.logger",
            "log.origin.file.name",
            "log.origin.function",
            "log.syslog.facility.name",
            "log.syslog.severity.name",
            "network.application",
            "network.community_id",
            "network.direction",
            "network.iana_number",
            "network.name",
            "network.protocol",
            "network.transport",
            "network.type",
            "observer.geo.city_name",
            "observer.geo.continent_name",
            "observer.geo.country_iso_code",
            "observer.geo.country_name",
            "observer.geo.name",
            "observer.geo.region_iso_code",
            "observer.geo.region_name",
            "observer.hostname",
            "observer.mac",
            "observer.name",
            "observer.os.family",
            "observer.os.full",
            "observer.os.kernel",
            "observer.os.name",
            "observer.os.platform",
            "observer.os.version",
            "observer.product",
            "observer.serial_number",
            "observer.type",
            "observer.vendor",
            "observer.version",
            "organization.id",
            "organization.name",
            "os.family",
            "os.full",
            "os.kernel",
            "os.name",
            "os.platform",
            "os.version",
            "package.architecture",
            "package.checksum",
            "package.description",
            "package.install_scope",
            "package.license",
            "package.name",
            "package.path",
            "package.version",
            "process.args",
            "process.executable",
            "process.hash.md5",
            "process.hash.sha1",
            "process.hash.sha256",
            "process.hash.sha512",
            "process.name",
            "process.thread.name",
            "process.title",
            "process.working_directory",
            "server.address",
            "server.as.organization.name",
            "server.domain",
            "server.geo.city_name",
            "server.geo.continent_name",
            "server.geo.country_iso_code",
            "server.geo.country_name",
            "server.geo.name",
            "server.geo.region_iso_code",
            "server.geo.region_name",
            "server.mac",
            "server.registered_domain",
            "server.top_level_domain",
            "server.user.domain",
            "server.user.email",
            "server.user.full_name",
            "server.user.group.domain",
            "server.user.group.id",
            "server.user.group.name",
            "server.user.hash",
            "server.user.id",
            "server.user.name",
            "service.ephemeral_id",
            "service.id",
            "service.name",
            "service.node.name",
            "service.state",
            "service.type",
            "service.version",
            "source.address",
            "source.as.organization.name",
            "source.domain",
            "source.geo.city_name",
            "source.geo.continent_name",
            "source.geo.country_iso_code",
            "source.geo.country_name",
            "source.geo.name",
            "source.geo.region_iso_code",
            "source.geo.region_name",
            "source.mac",
            "source.registered_domain",
            "source.top_level_domain",
            "source.user.domain",
            "source.user.email",
            "source.user.full_name",
            "source.user.group.domain",
            "source.user.group.id",
            "source.user.group.name",
            "source.user.hash",
            "source.user.id",
            "source.user.name",
            "threat.framework",
            "threat.tactic.id",
            "threat.tactic.name",
            "threat.tactic.reference",
            "threat.technique.id",
            "threat.technique.name",
            "threat.technique.reference",
            "trace.id",
            "transaction.id",
            "url.domain",
            "url.extension",
            "url.fragment",
            "url.full",
            "url.original",
            "url.password",
            "url.path",
            "url.query",
            "url.registered_domain",
            "url.scheme",
            "url.top_level_domain",
            "url.username",
            "user.domain",
            "user.email",
            "user.full_name",
            "user.group.domain",
            "user.group.id",
            "user.group.name",
            "user.hash",
            "user.id",
            "user.name",
            "user_agent.device.name",
            "user_agent.name",
            "user_agent.original.text",
            "user_agent.original",
            "user_agent.os.family",
            "user_agent.os.full",
            "user_agent.os.kernel",
            "user_agent.os.name",
            "user_agent.os.platform",
            "user_agent.os.version",
            "user_agent.version",
            "agent.hostname",
            "timeseries.instance",
            "cloud.image.id",
            "host.os.build",
            "host.os.codename",
            "kubernetes.pod.name",
            "kubernetes.pod.uid",
            "kubernetes.namespace",
            "kubernetes.node.name",
            "kubernetes.node.hostname",
            "kubernetes.replicaset.name",
            "kubernetes.deployment.name",
            "kubernetes.statefulset.name",
            "kubernetes.container.name",
            "jolokia.agent.version",
            "jolokia.agent.id",
            "jolokia.server.product",
            "jolokia.server.version",
            "jolokia.server.vendor",
            "jolokia.url",
            "event.original",
            "winlog.api",
            "winlog.activity_id",
            "winlog.computer_name",
            "winlog.event_data.AuthenticationPackageName",
            "winlog.event_data.Binary",
            "winlog.event_data.BitlockerUserInputTime",
            "winlog.event_data.BootMode",
            "winlog.event_data.BootType",
            "winlog.event_data.BuildVersion",
            "winlog.event_data.Company",
            "winlog.event_data.CorruptionActionState",
            "winlog.event_data.CreationUtcTime",
            "winlog.event_data.Description",
            "winlog.event_data.Detail",
            "winlog.event_data.DeviceName",
            "winlog.event_data.DeviceNameLength",
            "winlog.event_data.DeviceTime",
            "winlog.event_data.DeviceVersionMajor",
            "winlog.event_data.DeviceVersionMinor",
            "winlog.event_data.DriveName",
            "winlog.event_data.DriverName",
            "winlog.event_data.DriverNameLength",
            "winlog.event_data.DwordVal",
            "winlog.event_data.EntryCount",
            "winlog.event_data.ExtraInfo",
            "winlog.event_data.FailureName",
            "winlog.event_data.FailureNameLength",
            "winlog.event_data.FileVersion",
            "winlog.event_data.FinalStatus",
            "winlog.event_data.Group",
            "winlog.event_data.IdleImplementation",
            "winlog.event_data.IdleStateCount",
            "winlog.event_data.ImpersonationLevel",
            "winlog.event_data.IntegrityLevel",
            "winlog.event_data.IpAddress",
            "winlog.event_data.IpPort",
            "winlog.event_data.KeyLength",
            "winlog.event_data.LastBootGood",
            "winlog.event_data.LastShutdownGood",
            "winlog.event_data.LmPackageName",
            "winlog.event_data.LogonGuid",
            "winlog.event_data.LogonId",
            "winlog.event_data.LogonProcessName",
            "winlog.event_data.LogonType",
            "winlog.event_data.MajorVersion",
            "winlog.event_data.MaximumPerformancePercent",
            "winlog.event_data.MemberName",
            "winlog.event_data.MemberSid",
            "winlog.event_data.MinimumPerformancePercent",
            "winlog.event_data.MinimumThrottlePercent",
            "winlog.event_data.MinorVersion",
            "winlog.event_data.NewProcessId",
            "winlog.event_data.NewProcessName",
            "winlog.event_data.NewSchemeGuid",
            "winlog.event_data.NewTime",
            "winlog.event_data.NominalFrequency",
            "winlog.event_data.Number",
            "winlog.event_data.OldSchemeGuid",
            "winlog.event_data.OldTime",
            "winlog.event_data.OriginalFileName",
            "winlog.event_data.Path",
            "winlog.event_data.PerformanceImplementation",
            "winlog.event_data.PreviousCreationUtcTime",
            "winlog.event_data.PreviousTime",
            "winlog.event_data.PrivilegeList",
            "winlog.event_data.ProcessId",
            "winlog.event_data.ProcessName",
            "winlog.event_data.ProcessPath",
            "winlog.event_data.ProcessPid",
            "winlog.event_data.Product",
            "winlog.event_data.PuaCount",
            "winlog.event_data.PuaPolicyId",
            "winlog.event_data.QfeVersion",
            "winlog.event_data.Reason",
            "winlog.event_data.SchemaVersion",
            "winlog.event_data.ScriptBlockText",
            "winlog.event_data.ServiceName",
            "winlog.event_data.ServiceVersion",
            "winlog.event_data.ShutdownActionType",
            "winlog.event_data.ShutdownEventCode",
            "winlog.event_data.ShutdownReason",
            "winlog.event_data.Signature",
            "winlog.event_data.SignatureStatus",
            "winlog.event_data.Signed",
            "winlog.event_data.StartTime",
            "winlog.event_data.State",
            "winlog.event_data.Status",
            "winlog.event_data.StopTime",
            "winlog.event_data.SubjectDomainName",
            "winlog.event_data.SubjectLogonId",
            "winlog.event_data.SubjectUserName",
            "winlog.event_data.SubjectUserSid",
            "winlog.event_data.TSId",
            "winlog.event_data.TargetDomainName",
            "winlog.event_data.TargetInfo",
            "winlog.event_data.TargetLogonGuid",
            "winlog.event_data.TargetLogonId",
            "winlog.event_data.TargetServerName",
            "winlog.event_data.TargetUserName",
            "winlog.event_data.TargetUserSid",
            "winlog.event_data.TerminalSessionId",
            "winlog.event_data.TokenElevationType",
            "winlog.event_data.TransmittedServices",
            "winlog.event_data.UserSid",
            "winlog.event_data.Version",
            "winlog.event_data.Workstation",
            "winlog.event_data.param1",
            "winlog.event_data.param2",
            "winlog.event_data.param3",
            "winlog.event_data.param4",
            "winlog.event_data.param5",
            "winlog.event_data.param6",
            "winlog.event_data.param7",
            "winlog.event_data.param8",
            "winlog.event_id",
            "winlog.keywords",
            "winlog.channel",
            "winlog.record_id",
            "winlog.related_activity_id",
            "winlog.opcode",
            "winlog.provider_guid",
            "winlog.provider_name",
            "winlog.task",
            "winlog.user.identifier",
            "winlog.user.name",
            "winlog.user.domain",
            "winlog.user.type",
            "powershell.id",
            "powershell.pipeline_id",
            "powershell.runspace_id",
            "powershell.command.path",
            "powershell.command.name",
            "powershell.command.type",
            "powershell.command.value",
            "powershell.command.invocation_details.type",
            "powershell.command.invocation_details.related_command",
            "powershell.command.invocation_details.name",
            "powershell.command.invocation_details.value",
            "powershell.connected_user.domain",
            "powershell.connected_user.name",
            "powershell.engine.version",
            "powershell.engine.previous_state",
            "powershell.engine.new_state",
            "powershell.file.script_block_id",
            "powershell.file.script_block_text",
            "powershell.process.executable_version",
            "powershell.provider.new_state",
            "powershell.provider.name",
            "winlog.logon.type",
            "winlog.logon.id",
            "winlog.logon.failure.reason",
            "winlog.logon.failure.status",
            "winlog.logon.failure.sub_status",
            "sysmon.dns.status",
            "fields.*"
            ]

    actdatafields = body[rootKey]["settings"]["index"]["query"]["default_field"]
    assert  actdatafields.sort() == dataFields.sort(), "Winlogbeats data fields do not match"

def test_winlogbeat_search():
    # This test requires DC1 instance in cluster set up otherwise it will fail
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')
    username = os.getenv('ES_USERNAME', 'elastic')
    password = os.getenv('elastic', 'default_password')
    url = f"https://{es_host}:{es_port}/winlogbeat-*/_search"
    body = {
                "size": 1,
                "query": {
                    "term": {
                        "host.name": "DC1.lme.local"
                    }
                }
            }
    auth = HTTPBasicAuth(username, password)
    response = requests.get(url, auth=auth, verify=False, json = body)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = json.loads(response.text)
    datas = json.dump(data, open(f"{current_script_dir}/test_data/winlog_search_data.json", 'w'), indent = 4)

    assert data["hits"]["hits"][0]["_source"]["host"]["name"]=='DC1.lme.local'

    #Validating JSON Response schema
    schema = load_json_schema(f"{current_script_dir}/schemas/winlogbeat_search.json")
    try:
        validate(instance=response.text, schema=schema)
        print("JSON data is valid.")
    except ValidationError as ve:
        print("JSON data is invalid.")
        print(ve)