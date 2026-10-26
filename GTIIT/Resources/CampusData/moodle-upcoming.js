// Read-only, same-origin Moodle summary. Never export the session key, user ID,
// HTML, grades, submission contents or attachment links to the native app.
if (location.origin !== 'https://moodle.gtiit.edu.cn' || !window.M?.cfg?.sesskey || /\/login\//.test(location.pathname)) {
  return JSON.stringify({loginRequired:true,items:[],courses:0,checked:0,failed:0});
}
window.__gtiitUpcomingJob?.abort();
const controller = new AbortController();
controller.jobID = jobID;
window.__gtiitUpcomingJob = controller;
const signal = controller.signal;
const deadline = setTimeout(()=>controller.abort(), 100000);
const base = new URL(M.cfg.wwwroot);
if (base.origin !== location.origin || base.pathname.replace(/\/$/,'') !== '/moodle') throw Error('UNEXPECTED_ROOT');
const clean = x => String(x ?? '').replace(/\s+/g,' ').trim().slice(0,240);
const safeURL = (value, kind) => {
  try { const u = new URL(value, base.href+'/');
    if(u.origin !== base.origin || u.pathname !== '/moodle/mod/'+kind+'/view.php' || !/^\d+$/.test(u.searchParams.get('id')||'')) return null;
    return u.origin+u.pathname+'?id='+u.searchParams.get('id');
  } catch { return null; }
};
// A single request budget covers calendar RPCs, course pages and assignments.
// Cancellation drains queued work as well as aborting in-flight fetches.
const requestLimit=6, waiters=[];let activeRequests=0;
const acquire=()=>new Promise((resolve,reject)=>{
 const run=()=>{if(signal.aborted){reject(Error('CANCELLED'));return;}
  activeRequests++;resolve(()=>{activeRequests--;waiters.shift()?.();});};
 if(signal.aborted)reject(Error('CANCELLED'));else if(activeRequests<requestLimit)run();else waiters.push(run);
});
signal.addEventListener('abort',()=>{for(const run of waiters.splice(0))run();},{once:true});
const request = async (url, options={}) => {
  if(signal.aborted) throw Error('CANCELLED');
  const release=await acquire();
  const local = new AbortController();
  const stop=()=>local.abort(); signal.addEventListener('abort',stop,{once:true});
  const timer=setTimeout(stop,12000);
  try { const response=await fetch(url,{...options,credentials:'same-origin',signal:local.signal});
    if(!response.ok || new URL(response.url).origin!==base.origin || /\/login\//.test(new URL(response.url).pathname)) throw Error('UNAVAILABLE');
    const body = await response.text();
    return {text:async()=>body,json:async()=>JSON.parse(body)};
  } finally {clearTimeout(timer);signal.removeEventListener('abort',stop);release();}
};
const rpc=async(methodname,args)=>{
 const r=await request(base.href.replace(/\/$/,'')+'/lib/ajax/service.php?sesskey='+encodeURIComponent(M.cfg.sesskey),{
  method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify([{index:0,methodname,args}])});
 const q=(await r.json())[0]; if(!q || q.error!==false)throw Error('API_UNAVAILABLE');return q.data;
};
const html=async(url)=>{
 const r=await request(url);const doc=new DOMParser().parseFromString(await r.text(),'text/html');
 if(doc.querySelector('form#login,body#page-login-index'))throw Error('LOGIN_REQUIRED');return doc;
};
// Explicit dates in Moodle 3.9 status tables, interpreted in the campus zone.
const parseDate = value => {
 const s=clean(value), months=['january','february','march','april','may','june','july','august','september','october','november','december'];
 let m=s.match(/(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4}),?\s+(\d{1,2}):(\d{2})(?:\s*(AM|PM))?/i);
 let y,mo,d,h,mi;
 if(m){d=+m[1];mo=months.indexOf(m[2].toLowerCase())+1;y=+m[3];h=+m[4];mi=+m[5];if(m[6])h=h%12+(m[6].toUpperCase()==='PM'?12:0);}
 else {m=s.match(/(\d{4})\s*[年/-]\s*(\d{1,2})\s*[月/-]\s*(\d{1,2})\s*日?.*?(\d{1,2}):(\d{2})/);if(!m)return null;[y,mo,d,h,mi]=m.slice(1).map(Number);if(/下午/.test(s)&&h<12)h+=12;if(/上午/.test(s)&&h===12)h=0;}
 if(mo<1||mo>12||d<1||d>31||h>23||mi>59)return null;
 const n=Date.UTC(y,mo-1,d,h-8,mi)/1000, c=new Date(n*1000+8*3600000);
 return c.getUTCFullYear()===y&&c.getUTCMonth()===mo-1&&c.getUTCDate()===d?n:null;
};
// Moodle supplies in-progress courses. Explicit semester labels and dates further
// exclude old courses whose Moodle end date was never maintained by the teacher.
const campusNow = new Date(now*1000 + 8*3600000);
const month = campusNow.getUTCMonth()+1;
const year = typeof termYear === 'number' ? termYear : campusNow.getUTCFullYear()-(month<3?1:0);
const season = typeof termSeason === 'string' ? termSeason.toLowerCase() : (month<3||month>=10?'winter':month<7?'spring':'summer');
const seasonRank={winter:0,spring:1,summer:2};
const courseTerms = c => {
 const label=clean([c.fullname,c.shortname,c.coursecategory].join(' ')).toLowerCase();
 return [...label.matchAll(/(20\d{2})[\s_/-]*(winter|spring|summer|autumn|fall)/g),
         ...label.matchAll(/(winter|spring|summer|autumn|fall)[\s_/-]*(20\d{2})/g)]
   .map(m=>({year:+(/20\d{2}/.test(m[1])?m[1]:m[2]),season:(/20\d{2}/.test(m[1])?m[2]:m[1]).replace(/autumn|fall/,'winter')}));
};
const courseTerm = c => {
 const terms=courseTerms(c);
 if(terms.length){
   const t=terms.sort((a,b)=>a.year-b.year||(seasonRank[a.season]??0)-(seasonRank[b.season]??0))[0];
   return t.season[0].toUpperCase()+t.season.slice(1)+' '+t.year;
 }
 // Courses without a term label: keep an active course in the current term,
 // otherwise let it fall into the history module.
 const start=Number(c.startdate)||0, end=Number(c.enddate)||0;
 if(start<=now+180*86400 && (end===0 || end>=now-30*86400))
   return season[0].toUpperCase()+season.slice(1)+' '+year;
 return null;
};
const termScore = (y,s) => y*3 + (s==='winter'?2:s==='spring'?0:1);
const currentCourse = c => {
 const terms=courseTerms(c);
 const currentScore=termScore(year,season);
 // Academic order: Winter 2025 < Spring 2026 < Summer 2026 < Winter 2026 < Spring 2027.
 // Keep the current term and later terms, while the full course list still
 // carries older terms into the native history archive.
 if(terms.length && !terms.some(t=>termScore(t.year,t.season)>=currentScore))return false;
 if(c.visible===false||c.visible===0)return false;
 if(Number(c.startdate)>now)return false;
 if(Number(c.enddate)>0 && Number(c.enddate)<now)return false;
 return true;
};
const map=new Map();let failed=0,checked=0,courseCount=0,courses=[],allCourses=[];
const merge = item => {
 if(!item.url || !item.name)return;
 const old=map.get(item.url);
 if(!old)map.set(item.url,item);
 else if(item.source==='assignment' && item.checkedAt===now){const opened=item.opened??old.opened;Object.assign(old,item,{opened});}
 else if(old.source==='assignment' && old.checkedAt===now && item.source==='calendar'){if(!old.opened&&item.opened)old.opened=item.opened;}
 else {for(const k of ['due','opened'])if(item[k])old[k]=item[k];if(item.status&&item.status!=='unknown')old.status=item.status;if(item.source==='assignment')old.source='assignment';}
};
try {
 const start=Math.floor(now)-2*86400,end=Math.floor(now)+14*86400;
 const calendarJob=Promise.all([
  ['core_calendar_get_action_events_by_timesort',{timesortfrom:start,timesortto:end,limitnum:50}],
  ['core_calendar_get_calendar_upcoming_view',{}]
 ].map(async([method,args])=>{try {const data=await rpc(method,args);if((data.events||[]).length>=50)failed++;for(const e of data.events||[]){
   const kind=e.modulename;if(!['assign','quiz'].includes(kind))continue;
   if(e.course && !currentCourse(e.course))continue;
   const url=safeURL(e.url,kind);const type=String(e.eventtype||'');
   if(!['open','due','close'].includes(type))continue;
   merge({url,name:clean(e.name),course:clean(e.course?.fullname),courseID:Number(e.course?.id)||null,due:type==='open'?null:Number(e.timestart)||null,opened:type==='open'?Number(e.timestart)||null:null,status:'unknown',source:'calendar',kind});
 }}catch {failed++;}}));
 const cachedDirectory = typeof cachedDirectoryJSON === 'string' ? JSON.parse(cachedDirectoryJSON) : [];
 const directoryRefreshed = typeof refreshDirectory !== 'boolean' || refreshDirectory || !cachedDirectory.length || cachedDirectory.some(c=>typeof c.active!=='boolean');
 if (!directoryRefreshed) {
  allCourses=cachedDirectory;
  courses=cachedDirectory.filter(c=>c.active && (!c.term || c.term.toLowerCase()===season+' '+year));
 } else {
 let offset=0;
 for(let page=0;page<5;page++){
  let data;
  try { data=await rpc('core_course_get_enrolled_courses_by_timeline_classification',{classification:'all',limit:100,offset,sort:'fullname'}); }
  catch { data=await rpc('core_course_get_enrolled_courses_by_timeline_classification',{classification:'inprogress',limit:100,offset,sort:'fullname'}); }
  if(!Array.isArray(data.courses))throw Error('COURSES_UNAVAILABLE');
  const mapped=data.courses.map(c=>({id:Number(c.id),name:clean(c.fullname),shortname:clean(c.shortname),category:clean(c.coursecategory),term:courseTerm(c),active:currentCourse(c)})).filter(c=>Number.isSafeInteger(c.id)&&c.id>0);
  allCourses.push(...mapped);
  courses.push(...mapped.filter(c=>c.active));
  if(!data.courses.length || !data.nextoffset || data.nextoffset<=offset)break;
  offset=data.nextoffset;if(page===4)failed++;
 }
 }
 allCourses=[...new Map(allCourses.map(c=>[c.id,c])).values()].slice(0,150);
 courses=[...new Map(courses.map(c=>[c.id,c])).values()];courseCount=courses.length;
 if(courses.length>100){failed+=courses.length-100;courses=courses.slice(0,100);}
 window.__gtiitUpcomingDirectory={jobID,courses:allCourses};
 const priority=new Set(typeof priorityIDs !== 'undefined' ? priorityIDs : []);
 courses.sort((a,b)=>Number(priority.has(b.id))-Number(priority.has(a.id)));
 const cachedWork=new Map((typeof cachedItemsJSON==='string'?JSON.parse(cachedItemsJSON):[]).map(w=>[w.url,w]));
 const assignments=new Map();
 const pool=async(values,work)=>{let i=0;await Promise.all(Array.from({length:6},async()=>{while(i<values.length&&!signal.aborted){const v=values[i++];try{await work(v);}catch{failed++;}}}));};
 await pool(courses,async(c)=>{
   const doc=await html(base.origin+'/moodle/mod/assign/index.php?id='+c.id);
   // Index includes assignments from every section, including collapsed sections.
   for(const a of doc.querySelectorAll('a[href*="/mod/assign/view.php"]')){
     const url=safeURL(a.getAttribute('href'),'assign');if(url&&!assignments.has(url))assignments.set(url,{url,name:clean(a.textContent),course:c.name,courseID:c.id});
   }
   checked++;
 });
 let pages=[...assignments.values()];if(pages.length>240){failed+=pages.length-240;pages=pages.slice(0,240);}
 await pool(pages,async(a)=>{
   const cached=cachedWork.get(a.url);
   if(cached && cached.checkedAt && now-cached.checkedAt<6*3600 &&
      (cached.status==='submitted' || (cached.due && cached.due>now+7*86400))){
     merge({...cached,...a});return;
   }
   const previous=cachedWork.get(a.url);
   if(previous)merge({...previous,...a});
   const doc=await html(a.url);let due=null,opened=null,status='unknown',sawDue=false;
   for(const row of doc.querySelectorAll('.submissionstatustable tr')){
     const cells=[...row.children];if(cells.length<2)continue;const key=clean(cells[0].textContent),value=clean(cells[1].textContent);
     if(/^(Due date|截止日期|到期日|截止时间)$/i.test(key)){sawDue=true;due=parseDate(value);if(!due&&!/^-|无|none|not set/i.test(value))failed++;}
     if(/^(Submission status|提交状态)$/i.test(key)){
       if(/^(submitted for grading|已提交.*评|已提交评分)$/i.test(value))status='submitted';
       else if(/draft|草稿/i.test(value))status='draft';
       else if(/no attempt|no submission|not submitted|未尝试|未提交|尚未提交|尚未尝试/i.test(value))status='notSubmitted';
     }
   }
   // Newer Moodle date components supply machine timestamps with labelled rows.
   for(const el of doc.querySelectorAll('[data-region="activity-dates"] [data-timestamp]')){
     const t=Number(el.getAttribute('data-timestamp')),label=clean(el.parentElement?.textContent);
     if(t>0&&/due|截止|到期/i.test(label))due=t;
     if(t>0&&/open|opened|开放|开始/i.test(label))opened=t;
   }
   if(!sawDue&&!doc.querySelector('.submissionstatustable'))failed++;
   merge({...a,due,opened,status,source:'assignment',kind:'assign',checkedAt:now});
 });
 await calendarJob;
 if(signal.aborted)throw Error('CANCELLED');
 const activeIDs=new Set(courses.map(c=>c.id));
 return JSON.stringify({loginRequired:false,items:[...map.values()].filter(x=>(!x.courseID||activeIDs.has(x.courseID))).map(({courseID,...item})=>item),courses:courseCount,courseList:allCourses,directoryRefreshed,checked,failed});
} finally {controller.abort();clearTimeout(deadline);if(window.__gtiitUpcomingDirectory?.jobID===jobID)delete window.__gtiitUpcomingDirectory;if(window.__gtiitUpcomingJob===controller)delete window.__gtiitUpcomingJob;}
