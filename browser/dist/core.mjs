export const MAX_POINTS=200000, MAX_FACES=400000;
const fail=m=>{throw new Error(m)};
const finite=n=>typeof n==='number'&&Number.isFinite(n)&&Math.abs(n)<=1e6;
export const distance=(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]));
function point(p){if(!Array.isArray(p)||p.length!==3||!p.every(finite))fail('พิกัดไม่ถูกต้องหรือเกินขอบเขต');return p;}
export function validateModel(model){
 if(!Array.isArray(model.positions)||!model.positions.length||model.positions.length%3||model.positions.length>MAX_POINTS*3||!model.positions.every(finite))fail('ข้อมูลจุดไม่ถูกต้อง หรือเกิน 200,000 จุด');
 if(!Array.isArray(model.indices)||model.indices.length%3||model.indices.length>MAX_FACES*3||!model.indices.every(v=>Number.isInteger(v)&&v>=0&&v<model.positions.length/3))fail('ดัชนีพื้นผิวไม่ถูกต้อง');
 const records=model.measurements??[];if(!Array.isArray(records)||records.length>1000)fail('รายการวัดไม่ถูกต้อง');
 for(const r of records){point(r.a);point(r.b);if(typeof r.name!=='string'||!r.name.trim()||r.name.length>256||typeof r.date!=='string'||!Number.isFinite(Date.parse(r.date)))fail('ผลวัดไม่ถูกต้อง');}
 return {...model,measurements:records};
}
export function parseScan(text,name,scale=1){
 if(![1,.01,.001].includes(scale))fail('หน่วยไม่ถูกต้อง');
 let positions=[],indices=[],measurements=[];
 const add=p=>{point(p);if(positions.length>=MAX_POINTS*3)fail('ไฟล์เกิน 200,000 จุด');positions.push(...p.map(n=>n*scale));};
 const ext=name.split('.').pop().toLowerCase();
 if(ext==='json'){
  const data=JSON.parse(text);
  if(data.format==='3117-web-project'&&data.version===1){return validateModel({...data,name:String(data.name||name),positions:data.positions,indices:data.indices});}
  if(!Array.isArray(data))fail('รองรับ mesh JSON จากแอป 3117 หรือโปรเจกต์เว็บเท่านั้น');
  // Native archives are always metres; the source-unit selector does not rescale them.
  scale=1;
  for(const mesh of data){let t=mesh.transform?.values;if(!Array.isArray(t)||t.length!==16||!t.every(Number.isFinite)||!Array.isArray(mesh.vertices)||!Array.isArray(mesh.triangles))fail('mesh JSON ไม่ถูกต้อง');
   const offset=positions.length/3;
   for(const p of mesh.vertices){point([p.x,p.y,p.z]);add([t[0]*p.x+t[4]*p.y+t[8]*p.z+t[12],t[1]*p.x+t[5]*p.y+t[9]*p.z+t[13],t[2]*p.x+t[6]*p.y+t[10]*p.z+t[14]]);}
   for(const f of mesh.triangles){for(const i of [f.a,f.b,f.c]){if(!Number.isInteger(i)||i<0||i>=mesh.vertices.length)fail('ดัชนี mesh JSON ไม่ถูกต้อง');indices.push(offset+i);}if(indices.length>MAX_FACES*3)fail('พื้นผิวมากเกินไป');}
  }
 }else if(ext==='obj'){
  for(const raw of text.split(/\r?\n/)){const tokens=raw.trim().split(/\s+/);if(tokens[0]==='v'){if(tokens.length<4)fail('OBJ vertex ไม่ครบ');add(tokens.slice(1,4).map(Number));}
   if(tokens[0]==='f'){const parts=tokens.slice(1);if(parts.length<3||parts.length>100)fail('OBJ face ไม่ถูกต้อง');const face=parts.map(s=>{const i=Number(s.split('/')[0]);if(!Number.isInteger(i)||i===0)fail('OBJ index ไม่ถูกต้อง');return i<0?positions.length/3+i:i-1;});for(let i=1;i<face.length-1;i++)indices.push(face[0],face[i],face[i+1]);if(indices.length>MAX_FACES*3)fail('พื้นผิวมากเกินไป');}
  }
 }else if(ext==='xyz'){
  for(const line of text.split(/\r?\n/)){if(!line.trim()||line.trim().startsWith('#'))continue;const cells=line.trim().split(/\s+/);if(cells.length!==3)fail('XYZ ต้องมี x y z สามคอลัมน์');add(cells.map(Number));}
 }else if(ext==='ply'){
  const lines=text.split(/\r?\n/),end=lines.findIndex(l=>l.trim()==='end_header');if(lines[0].trim()!=='ply'||end<0||!lines.slice(0,end).some(l=>l.trim()==='format ascii 1.0'))fail('รองรับ PLY แบบ ASCII 1.0 เท่านั้น');
  let count=0,props=[],inVertex=false,seenElement=false;
  for(const line of lines.slice(1,end)){const p=line.trim().split(/\s+/);if(p[0]==='element'){if(!seenElement&&p[1]!=='vertex')fail('PLY ต้องเริ่มด้วย vertex');seenElement=true;inVertex=p[1]==='vertex';if(inVertex){count=Number(p[2]);if(!Number.isInteger(count)||count<1||count>MAX_POINTS)fail('จำนวน vertex ไม่ถูกต้อง');}}if(p[0]==='property'&&inVertex){if(p[1]==='list')fail('ไม่รองรับ list ใน vertex');props.push(p[2]);}}
  const cols=['x','y','z'].map(k=>props.indexOf(k));if(cols.some(i=>i<0))fail('PLY ไม่มี x y z');
  for(let i=0;i<count;i++){const cells=lines[end+1+i]?.trim().split(/\s+/);if(!cells||cells.length<props.length)fail('ข้อมูล PLY ไม่ครบ');add(cols.map(c=>Number(cells[c])));}
 }else fail('ไม่รองรับไฟล์ชนิดนี้');
 return validateModel({format:'3117-web-project',version:1,name,positions,indices,measurements,source:ext==='ply'?'PLY point cloud':ext.toUpperCase(),unit:'m',synthetic:false});
}
export function demoModel(){return {format:'3117-web-project',version:1,name:'ห้องตัวอย่าง · 4 × 3 × 2.8 m',unit:'m',source:'SYNTHETIC DEMO',synthetic:true,measurements:[],positions:[0,0,0,4,0,0,4,0,3,0,0,3,0,2.8,0,4,2.8,0,4,2.8,3,0,2.8,3],indices:[0,2,1,0,3,2,0,1,5,0,5,4,0,4,7,0,7,3,3,7,6,3,6,2]};}
export function csv(model){const quote=s=>'"'+(/^[\s]*[=+@-]|^[\t\r\n]/.test(String(s))?"'":'')+String(s).replaceAll('"','""')+'"';const rows=['project,label,date_utc,unit,a_x,a_y,a_z,b_x,b_y,b_z,distance_m,source,accuracy'];for(const r of model.measurements)rows.push([quote(model.name),quote(r.name),quote(r.date),'m',...r.a,...r.b,distance(r.a,r.b),quote(model.synthetic?'synthetic_demo':model.source),'not_survey_validated'].join(','));return '\uFEFF'+rows.join('\r\n')+'\r\n';}
