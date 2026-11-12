#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
python3 -I -S -B - "$root" <<'PY'
import json, os, pathlib, socket, socketserver, subprocess, sys, tempfile, threading, time, types, unittest
ROOT=pathlib.Path(sys.argv[1]); WRAPPER=ROOT/'deploy/vps/operator/agent-vps-d0-identity-audit'
source=WRAPPER.read_text().split("<<'PY'",1)[1].rsplit('\nPY',1)[0]
m=types.ModuleType('audit'); exec(compile(source,'collector','exec'),m.__dict__)

class Handler(socketserver.BaseRequestHandler):
 def handle(self):
  data=b''
  while b'\r\n\r\n' not in data:
   part=self.request.recv(4096)
   if not part: return
   data+=part
  self.server.requests.append(data.split(b'\r\n',1)[0])
  mode=self.server.mode
  path=data.split(b' ',2)[1].decode()
  if path=='/version' and mode.startswith('identity'):
   values={'identity_version_low':{'ApiVersion':'1.40','MinAPIVersion':'1.24'},'identity_version_high':{'ApiVersion':'1.55','MinAPIVersion':'1.44'},'identity_version_missing':{'ApiVersion':'1.55'},'identity_version_bad':{'ApiVersion':'oops','MinAPIVersion':'1.40'},'identity_version_inverted':{'ApiVersion':'1.40','MinAPIVersion':'1.55'}}
   if mode=='identity_version_fail': self.request.sendall(b'HTTP/1.1 500 Error\r\nContent-Length: 0\r\n\r\n'); return
   body=json.dumps(values.get(mode,{'ApiVersion':'1.55','MinAPIVersion':'1.40'})).encode()
   self.request.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: '+str(len(body)).encode()+b'\r\n\r\n'+body); return
  if mode.startswith('identity'):
   path=data.split(b' ',2)[1].decode(); ids=['1'*64,'2'*64,'3'*64]; services=('postgres','pgbouncer','redis')
   labels=lambda service: {'com.docker.compose.project':m.PROJECT,'com.docker.compose.service':service}
   if path==m.CONTAINERS_PATH:
    payload=[{'Id':ident,'Names':['/'+m.PROJECT+'-'+service+'-1'],'Labels':labels(service)} for ident,service in zip(ids,services)]
    if mode=='identity_duplicate': payload.append(payload[0])
    if mode=='identity_bad_id': payload[0]['Id']='x'*64
   elif path.startswith(m.API+'/networks/'):
    edge=path.endswith(m.EDGE); name=m.EDGE if edge else m.DATA; logical='eventsales_edge' if edge else 'eventsales_data'
    payload={'Id':('b' if edge else 'a')*64,'Name':name,'Driver':'bridge','Internal':not edge,'Labels':{'com.docker.compose.project':m.PROJECT,'com.docker.compose.network':logical},'Containers':{}}
    if mode=='identity_bad_label' and edge: payload['Labels']['com.docker.compose.network']='wrong'
    if mode=='identity_bad_network_id' and edge: payload['Id']='bad'
    if mode=='identity_edge_intruder' and edge: payload['Containers']['f'*64]={'Name':'intruder'}
    if mode=='identity_data_intruder' and not edge: payload['Containers']['f'*64]={'Name':'intruder'}
    if mode=='identity_data_bad_member_name' and not edge: payload['Containers'][ids[0]]={'Name':'wrong'}
    if mode=='identity_known_data_member' and not edge: payload['Containers'][ids[0]]={'Name':m.PROJECT+'-postgres-1'}
    if mode=='identity_missing_members' and edge: del payload['Containers']
   elif path==m.API+'/volumes/'+m.VOLUME:
    payload={'Name':m.VOLUME,'Driver':'local','Scope':'local','Labels':{'com.docker.compose.project':m.PROJECT,'com.docker.compose.volume':'postgres_data'},'Mountpoint':'/SENSITIVE_SENTINEL'}
    if mode=='identity_missing_mountpoint': del payload['Mountpoint']
   else:
    ident=path.split('/')[-2]; i=ids.index(ident); service=services[i]
    if mode=='identity_gap_then_transport' and service=='pgbouncer':
     self.request.sendall(b'HTTP/1.1 500 Error\r\nContent-Length: 0\r\n\r\n'); return
    payload={'Id':ident,'Name':'/'+m.PROJECT+'-'+service+'-1','Config':{'Image':m.IMAGES[i],'Labels':labels(service),'Env':['SENSITIVE_SENTINEL']},'State':{'Status':'exited','Running':False,'Restarting':False},'RestartCount':0,'NetworkSettings':{'Networks':{m.DATA:{'NetworkID':'a'*64}}},'Mounts':[]}
    if service=='postgres': payload['Mounts'].append({'Type':'volume','Name':m.VOLUME,'Destination':'/var/lib/postgresql','RW':True,'Source':'/SENSITIVE_SENTINEL','Driver':'local'})
    if mode=='identity_bad_mount' and service=='postgres': payload['Mounts'][0]['Name']='wrong'
    if mode=='identity_bad_source' and service=='postgres': payload['Mounts'][0]['Source']='/SENSITIVE_SENTINEL_WRONG'
    if mode=='identity_missing_source' and service=='postgres': del payload['Mounts'][0]['Source']
    if mode=='identity_bad_driver' and service=='postgres': payload['Mounts'][0]['Driver']='wrong'
    if mode=='identity_unknown_bind' and service=='redis': payload['Mounts'].append({'Type':'bind','Destination':'/unapproved-data','Source':'/SENSITIVE_SENTINEL','RW':False})
    if mode=='identity_unknown_tmpfs' and service=='redis': payload['Mounts'].append({'Type':'tmpfs','Destination':'/unapproved-data','RW':True})
    if mode=='identity_secret_bind' and service=='postgres': payload['Mounts'].append({'Type':'bind','Destination':'/run/secrets/postgres_bootstrap_password','Source':'/SENSITIVE_SENTINEL','RW':False})
    if mode=='identity_precedence' and service=='postgres': payload['Mounts'].append({'Type':'bind','Destination':'/run/secrets/postgres_bootstrap_password','Source':'/SENSITIVE_SENTINEL','RW':False})
    if mode=='identity_precedence' and service=='redis': payload['Mounts'].append({'Type':'volume','Name':'unexpected','Destination':'/extra','RW':True})
    if mode=='identity_mismatch_then_gap' and service=='postgres': payload['Mounts'][0]['Source']='/SENSITIVE_SENTINEL_WRONG'
    if mode=='identity_mismatch_then_gap' and service=='redis': payload['Mounts'].append({'Type':'bind','Destination':'/run/secrets/redis_users_acl','Source':'/SENSITIVE_SENTINEL','RW':False})
    if mode=='identity_gap_then_transport' and service=='postgres': payload['Mounts'].append({'Type':'bind','Destination':'/run/secrets/postgres_bootstrap_password','Source':'/SENSITIVE_SENTINEL','RW':False})
    if mode=='identity_changed_id' and service=='postgres': payload['Id']='f'*64
    if mode=='identity_extra_volume' and service=='postgres': payload['Mounts'].append({'Type':'volume','Name':'unexpected','Destination':'/extra','RW':True})
    if mode in ('identity_pgbouncer_volume','identity_redis_volume') and service==mode.split('_')[1]: payload['Mounts'].append({'Type':'volume','Name':m.VOLUME,'Destination':'/extra','RW':True})
    if mode=='identity_running_flag' and service=='postgres': payload['State']['Running']=True
    if mode=='identity_restarting_flag' and service=='postgres': payload['State']['Restarting']=True
    if mode=='identity_missing_flag' and service=='postgres': del payload['State']['Running']
    if mode=='identity_no_endpoint': payload['NetworkSettings']['Networks'][m.DATA]['NetworkID']=''
   body=json.dumps(payload).encode()
   self.request.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: '+str(len(body)).encode()+b'\r\n\r\n'+body); return
  if mode=='disconnect': return
  variants={'chunked':b'Transfer-Encoding: chunked\r\n\r\n2\r\nnu\r\n2\r\nll\r\n0\r\n\r\n', 'bad_chunk':b'Transfer-Encoding: chunked\r\n\r\nZZ\r\nnull\r\n0\r\n\r\n', 'duplicate':b'Content-Length: 4\r\nContent-Length: 4\r\n\r\nnull', 'conflict':b'Content-Length: 4\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n', 'unsupported_encoding':b'Transfer-Encoding: gzip\r\n\r\nnull', 'truncated':b'Content-Length: 10\r\n\r\nnull', 'large_header':b'X-Long: '+b'a'*20000+b'\r\nContent-Length: 4\r\n\r\nnull'}
  if mode in variants:
   try: self.request.sendall(b'HTTP/1.1 200 OK\r\n'+variants[mode])
   except OSError: pass
   return
  if mode=='stall': time.sleep(1); return
  if mode=='drip':
   try:
    for b in b'HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nnull':
     self.request.sendall(bytes([b])); time.sleep(.04)
   except OSError: pass
   return
  status=b'302 Found' if mode=='redirect' else b'500 Error' if mode=='failure' else b'200 OK'
  body=b'SENSITIVE_SENTINEL' if mode=='malformed' else b'x'*(m.MAX_BODY+1) if mode=='oversized' else b'null'
  try: self.request.sendall(b'HTTP/1.1 '+status+b'\r\nContent-Length: '+str(len(body)).encode()+b'\r\n\r\n'+body)
  except OSError: pass

class Server(socketserver.ThreadingUnixStreamServer):
 daemon_threads=True

class SecurityTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
  self.path=str(pathlib.Path(self.tmp.name)/'docker.sock'); self.server=Server(self.path,Handler)
  self.server.mode='normal'; self.server.requests=[]
  self.thread=threading.Thread(target=self.server.serve_forever,daemon=True); self.thread.start()
  self.addCleanup(self.server.server_close); self.addCleanup(self.server.shutdown)
  m.SOCKET_PATH=self.path; m.TRUSTED_PARENT=self.tmp.name; m.EXPECTED_SOCKET_UID=os.getuid(); m.EXPECTED_PEER_UID=os.getuid()
  m.REQUEST_SECONDS=.25; m.deadline=time.monotonic()+.45; m.version_accepted=True; m.request_count=0
 def test_fixed_requests(self):
  self.assertIsNone(m.get_json(m.CONTAINERS_PATH))
  self.assertEqual(self.server.requests,[b'GET '+m.CONTAINERS_PATH.encode()+b' HTTP/1.1'])
 def test_denied_paths(self):
  for path in ('/containers/create','/v1.41/containers/abc/json','http://example.invalid/'):
   with self.subTest(path=path), self.assertRaises(m.AuditError): m.get_json(path)
  self.assertEqual(self.server.requests,[])
 def test_failures_and_absolute_timeout(self):
  for mode in ('disconnect','stall','drip','redirect','failure','malformed','oversized','bad_chunk','duplicate','conflict','unsupported_encoding','truncated','large_header'):
   with self.subTest(mode=mode):
    self.server.mode=mode; m.deadline=time.monotonic()+.45; m.request_count=0
    start=time.monotonic()
    with self.assertRaises(m.AuditError) as caught: m.get_json(m.CONTAINERS_PATH)
    self.assertLess(time.monotonic()-start,.8)
    self.assertNotIn('SENSITIVE_SENTINEL',str(caught.exception))
 def test_chunked_success(self):
  self.server.mode='chunked'; self.assertIsNone(m.get_json(m.CONTAINERS_PATH))
 def test_no_process_or_signals(self):
  self.assertNotIn('import subprocess',source)
  self.assertNotIn('os.kill',source)
  self.assertNotIn('import signal',source)
 def test_privileged_entry_and_sudoers(self):
  self.assertTrue(WRAPPER.is_file() and not WRAPPER.is_symlink())
  sudoers=WRAPPER.with_name(WRAPPER.name+'.sudoers')
  self.assertFalse(sudoers.is_symlink())
  self.assertEqual(sudoers.read_text(),'agentops ALL=(root) NOPASSWD: /usr/local/sbin/agent-vps-d0-identity-audit ""\n')
  prefix=WRAPPER.read_text().split("<<'PY'",1)[0]
  with tempfile.TemporaryDirectory() as td:
   script=pathlib.Path(td)/'entry'; script.write_text(prefix+"<<'PY'\nprint('ENTRY')\nPY\n"); script.chmod(0o700)
   result=subprocess.run([str(script),'arg'],capture_output=True,timeout=3); self.assertEqual(result.returncode,64)
   if os.geteuid()!=0:
    result=subprocess.run([str(script)],capture_output=True,timeout=3); self.assertEqual(result.returncode,77)
   hostile=pathlib.Path(td)/'hostile'; hostile.write_text('echo SENSITIVE_SENTINEL')
   script.write_text(prefix.replace('EUID != 0','EUID != '+str(os.geteuid()))+"<<'PY'\nimport os\nassert not any(k.startswith(('BASH_','PYTHON','LD_')) for k in os.environ)\nprint('ENTRY')\nPY\n")
   result=subprocess.run([str(script)],env=dict(os.environ,BASH_ENV=str(hostile),PYTHONPATH=str(hostile)),capture_output=True,timeout=3)
   self.assertEqual(result.returncode,0); self.assertEqual(result.stdout,b'ENTRY\n'); self.assertNotIn(b'SENSITIVE_SENTINEL',result.stderr)
 def test_absolute_deadline_under_partial_response(self):
  self.server.mode='drip'; m.REQUEST_SECONDS=2; m.deadline=time.monotonic()+.2
  start=time.monotonic()
  with self.assertRaises(m.AuditError): m.get_json(m.CONTAINERS_PATH)
  self.assertLess(time.monotonic()-start,.6)
 def test_socket_owner_mismatch(self):
  m.EXPECTED_SOCKET_UID=os.getuid()+1
  with self.assertRaises(m.AuditError): m.get_json(m.CONTAINERS_PATH)
  self.assertEqual(self.server.requests,[])
 def test_socket_world_writable_rejected(self):
  os.chmod(self.path,0o666)
  with self.assertRaises(m.AuditError): m.get_json(m.CONTAINERS_PATH)
  self.assertEqual(self.server.requests,[])
 def test_socket_replaced_during_connect(self):
  original=m.os.stat; calls=0
  def changed(path,*args,**kwargs):
   nonlocal calls
   result=original(path,*args,**kwargs)
   if path=='docker.sock' and 'dir_fd' in kwargs:
    calls+=1
    if calls==2:
     values=list(result); values[1]+=1; return os.stat_result(values)
   return result
  m.os.stat=changed
  try:
   with self.assertRaises(m.AuditError): m.get_json(m.CONTAINERS_PATH)
  finally: m.os.stat=original
  self.assertEqual(self.server.requests,[])
 def test_unsafe_parent_rejected(self):
  os.chmod(self.tmp.name,0o777)
  with self.assertRaises(m.AuditError): m.get_json(m.CONTAINERS_PATH)
  self.assertEqual(self.server.requests,[])
 def test_request_count_bounded(self):
  m.request_count=m.MAX_REQUESTS
  with self.assertRaises(m.AuditError): m.get_json(m.CONTAINERS_PATH)
  self.assertEqual(self.server.requests,[])
 def test_current_identity_and_rejections(self):
  for mode in ('identity','identity_no_endpoint','identity_known_data_member','identity_duplicate','identity_bad_id','identity_bad_label','identity_bad_network_id','identity_changed_id','identity_bad_mount','identity_bad_source','identity_missing_source','identity_missing_mountpoint','identity_bad_driver','identity_unknown_bind','identity_unknown_tmpfs','identity_secret_bind','identity_precedence','identity_mismatch_then_gap','identity_gap_then_transport','identity_edge_intruder','identity_data_intruder','identity_data_bad_member_name','identity_missing_members','identity_extra_volume','identity_pgbouncer_volume','identity_redis_volume','identity_running_flag','identity_restarting_flag','identity_missing_flag','identity_version_low','identity_version_high','identity_version_missing','identity_version_bad','identity_version_inverted','identity_version_fail'):
   with self.subTest(mode=mode):
    self.server.mode=mode; self.server.requests=[]
    read_fd,write_fd=os.pipe(); saved=os.dup(1)
    try:
     os.dup2(write_fd,1); code=m.main()
    finally:
     os.dup2(saved,1); os.close(saved); os.close(write_fd)
    output=os.read(read_fd,16384); os.close(read_fd)
    self.assertNotIn(b'SENSITIVE_SENTINEL',output)
    if mode in ('identity','identity_no_endpoint','identity_known_data_member'): self.assertEqual(len(self.server.requests),8)
    if mode.startswith('identity_version_'): self.assertEqual(self.server.requests,[b'GET /version HTTP/1.1'])
    self.assertTrue(all(item.startswith(b'GET ') for item in self.server.requests))
    if mode in ('identity','identity_no_endpoint','identity_known_data_member'):
     self.assertNotEqual(code,0); self.assertIn(b'CURRENT_IDENTITY=UNVERIFIED',output); self.assertIn(b'COLLECTION_RESULT=COMPLETE',output)
     self.assertIn(b'COLLECTION_ATOMIC=NO',output); self.assertIn(b'HISTORICAL_CONTINUITY=UNVERIFIED',output); self.assertIn(b'D0_CURRENT_BASELINE=NOT_ACCEPTED',output)
     if mode=='identity_no_endpoint': self.assertIn(b'POSTGRES_ENDPOINT_ID=UNAVAILABLE_STOPPED',output)
    else:
     self.assertNotEqual(code,0); self.assertNotIn(b'CURRENT_IDENTITY=MATCH',output)
     if mode in ('identity_missing_members','identity_missing_flag'): self.assertIn(b'CURRENT_IDENTITY=UNVERIFIED',output)
     if mode in ('identity_missing_source','identity_missing_mountpoint','identity_unknown_bind','identity_unknown_tmpfs','identity_secret_bind'): self.assertIn(b'CURRENT_IDENTITY=UNVERIFIED',output)
     if mode in ('identity_secret_bind','identity_precedence','identity_mismatch_then_gap'): self.assertEqual(len(self.server.requests),8); self.assertIn(b'COLLECTION_RESULT=COMPLETE',output)
     if mode=='identity_gap_then_transport': self.assertEqual(len(self.server.requests),7); self.assertIn(b'COLLECTION_RESULT=INCOMPLETE',output); self.assertIn(b'STOP=D0_HTTP_STATUS',output)
     if mode in ('identity_bad_source','identity_bad_driver'): self.assertIn(b'CURRENT_IDENTITY=MISMATCH',output)
     if mode in ('identity_precedence','identity_mismatch_then_gap','identity_edge_intruder','identity_data_intruder','identity_extra_volume','identity_running_flag'): self.assertIn(b'CURRENT_IDENTITY=MISMATCH',output)

unittest.main(argv=['identity-audit-tests'],verbosity=2)
PY
