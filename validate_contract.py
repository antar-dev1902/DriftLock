"""DriftLock 2.0 v1 contract validator. Python stdlib only; macOS & Windows.

Usage: python validate_contract.py contracts/fixtures
       python validate_contract.py path/to/your/nav_frames.jsonl
"""
import json, sys, pathlib, hashlib
ROOT = pathlib.Path(__file__).resolve().parent
CONTRACT = json.loads((ROOT / 'DRIFTLOCK_SHARED_CONTRACT_v1.json').read_text(encoding='utf-8'))
EXPECTED = CONTRACT['sha256_without_sha256_field']
canon = {k:v for k,v in CONTRACT.items() if k != 'sha256_without_sha256_field'}
ACTUAL = hashlib.sha256(json.dumps(canon,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
if ACTUAL != EXPECTED:
    raise SystemExit('CONTRACT HASH FAILURE: canonical contract was changed. All four owners must ACK schema changes.')
SCHEMAS = {
'driftlock.sensor.v1': ('SensorSample', ['schema','session_id','t_ms','source','imu','gnss']),
'driftlock.nav.v1': ('NavFrame', ['schema','session_id','t_ms','source','outage_state','predicted','motion','uncertainty','road_match','versions']),
'driftlock.truth.v1': ('GroundTruth', ['schema','session_id','t_ms','lat_deg','lon_deg','provenance']),
'driftlock.benchmark.v1': ('BenchmarkSummary', ['schema','dataset_id','tested_sessions','outage_seconds','methods','provenance']),
'driftlock.mission.v1': ('MissionSummary', ['schema','session_id','source','started_at_utc','duration_ms','engine_version','model_version','benchmark_id','consent_to_upload']),
'driftlock.voice_state.v1': ('VoiceState', ['schema','session_id','t_ms','outage_state','radius_95_m','calibrated'])
}
def keys(o, expected, ctx):
    if not isinstance(o, dict):raise ValueError(f'{ctx}: expected object')
    missing = sorted(set(expected)-set(o)); extra=sorted(set(o)-set(expected))
    if missing or extra:raise ValueError(f'{ctx}: missing={missing}; unexpected={extra}')
def num(x,ctx,nullable=False):
    if nullable and x is None:return
    if isinstance(x,bool) or not isinstance(x,(int,float)):
        raise ValueError(f'{ctx}: expected number'+(' or null' if nullable else ''))
def integer(x,ctx):
    if isinstance(x,bool) or not isinstance(x,int) or x<0:raise ValueError(f'{ctx}: expected nonnegative integer')
def enum(x,allowed,ctx):
    if x not in allowed:raise ValueError(f'{ctx}: expected one of {allowed}; got {x!r}')
def check_latlon(o,ctx,allow_null=False):
    for k in ('lat_deg','lon_deg'):
        num(o[k],ctx+'.'+k,nullable=allow_null)
        if o[k] is not None and not (-90<=o[k]<=90 if k=='lat_deg' else -180<=o[k]<=180):
            raise ValueError(f'{ctx}.{k}: outside valid range')
def validate(o):
    if not isinstance(o,dict):raise ValueError('record is not an object')
    schema=o.get('schema')
    if schema not in SCHEMAS:raise ValueError('unknown schema '+repr(schema))
    type_name,req=SCHEMAS[schema];keys(o,req,type_name)
    if 'session_id' in o and (not isinstance(o['session_id'],str) or not o['session_id']):raise ValueError('missing session_id')
    if 't_ms' in o:integer(o['t_ms'],'t_ms')
    if 'source' in o:enum(o['source'],['recorded','simulated','live'],'source')
    if schema=='driftlock.sensor.v1':
        keys(o['imu'],['ax_mps2','ay_mps2','az_mps2','gx_radps','gy_radps','gz_radps'],'imu')
        for k,v in o['imu'].items():num(v,'imu.'+k)
        keys(o['gnss'],['available','lat_deg','lon_deg','speed_mps','horizontal_accuracy_m'],'gnss')
        g=o['gnss']
        if not isinstance(g['available'],bool):raise ValueError('gnss.available must be bool')
        check_latlon(g,'gnss',allow_null=True)
        for k in ('speed_mps','horizontal_accuracy_m'):num(g[k],'gnss.'+k,nullable=True)
        if not g['available'] and any(g[k] is not None for k in ('lat_deg','lon_deg','speed_mps','horizontal_accuracy_m')):
            raise ValueError('unavailable GNSS must have null observations')
    elif schema=='driftlock.nav.v1':
        enum(o['outage_state'],['locked','blackout','reacquiring'],'outage_state')
        keys(o['predicted'],['lat_deg','lon_deg'],'predicted');check_latlon(o['predicted'],'predicted',True)
        keys(o['motion'],['speed_mps','heading_deg'],'motion')
        for k,v in o['motion'].items():num(v,'motion.'+k,True)
        if o['motion']['heading_deg'] is not None and not 0 <= o['motion']['heading_deg'] < 360:raise ValueError('heading must be [0,360)')
        keys(o['uncertainty'],['radius_95_m','calibrated'],'uncertainty')
        u=o['uncertainty']
        if not isinstance(u['calibrated'],bool):raise ValueError('uncertainty.calibrated must be bool')
        num(u['radius_95_m'],'radius_95_m',True)
        if not u['calibrated'] and u['radius_95_m'] is not None:raise ValueError('uncalibrated uncertainty radius must be null')
        keys(o['road_match'],['status','lat_deg','lon_deg'],'road_match')
        enum(o['road_match']['status'],['unavailable','ambiguous','matched'],'road_match.status')
        check_latlon(o['road_match'],'road_match',True)
        keys(o['versions'],['engine','ml_model'],'versions')
        if not isinstance(o['versions']['engine'],str) or not o['versions']['engine']:raise ValueError('missing engine version')
    elif schema=='driftlock.truth.v1':
        check_latlon(o,'truth')
        if not isinstance(o['provenance'],str) or not o['provenance']:raise ValueError('missing provenance')
    elif schema=='driftlock.benchmark.v1':
        integer(o['tested_sessions'],'tested_sessions');integer(o['outage_seconds'],'outage_seconds')
        if not isinstance(o['methods'],list):raise ValueError('methods must be a list')
        for i,m in enumerate(o['methods']):
            keys(m,['name','sample_count','mean_error_m','median_error_m','p90_error_m','max_error_m'],f'method[{i}]')
            integer(m['sample_count'],f'method[{i}].sample_count')
            for f in ['mean_error_m','median_error_m','p90_error_m','max_error_m']:num(m[f],f'method[{i}].{f}',True)
    elif schema=='driftlock.mission.v1':
        integer(o['duration_ms'],'duration_ms')
        if not isinstance(o['consent_to_upload'],bool):raise ValueError('consent_to_upload must be bool')
    elif schema=='driftlock.voice_state.v1':
        enum(o['outage_state'],['locked','blackout','reacquiring'],'outage_state')
        num(o['radius_95_m'],'radius_95_m',True)
        if not isinstance(o['calibrated'],bool):raise ValueError('calibrated must be bool')
        if not o['calibrated'] and o['radius_95_m'] is not None:raise ValueError('uncalibrated radius must be null')
    return schema

def records(p):
    if p.suffix == '.jsonl':
        for line_no,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
            if line.strip():yield line_no,json.loads(line)
    else:yield 1,json.loads(p.read_text(encoding='utf-8'))

def main():
    if len(sys.argv)!=2:
        print('Usage: python validate_contract.py <folder-or-.json/.jsonl-file>');sys.exit(2)
    p=pathlib.Path(sys.argv[1]);files=sorted(p.rglob('*.json'))+sorted(p.rglob('*.jsonl')) if p.is_dir() else [p]
    n=0; failures=[]; timing={}
    for f in files:
        for line_no,record in records(f):
            try:
                schema=validate(record)
                key=(str(f),record.get('session_id'),schema)
                if schema in ('driftlock.sensor.v1','driftlock.nav.v1','driftlock.truth.v1'):
                    prev=timing.get(key,-1)
                    if record['t_ms']<=prev:raise ValueError(f'non-increasing t_ms: previous={prev}, current={record["t_ms"]}')
                    timing[key]=record['t_ms']
                n+=1
            except Exception as e:failures.append(f'{f}:{line_no}: {e}')
    for f in failures:print('FAIL',f)
    print(f'CONTRACT {CONTRACT["contract_id"]}: {n} validated records, {len(failures)} failures; SHA-256 {EXPECTED[:16]}')
    sys.exit(1 if failures or not files else 0)
if __name__=='__main__':main()
