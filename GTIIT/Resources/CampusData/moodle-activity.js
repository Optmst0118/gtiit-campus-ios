// Read only labelled dates and the current user's attempt/submission state.
const activityClean = x => String(x ?? '').replace(/\s+/g,' ').trim().slice(0,240);
// Explicit dates in Moodle 3.9 status tables, interpreted in the campus zone.
const parseDate = value => {
 const s=activityClean(value), months=['january','february','march','april','may','june','july','august','september','october','november','december'];
 let m=s.match(/(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4}),?\s+(\d{1,2}):(\d{2})(?:\s*(AM|PM))?/i);
 let y,mo,d,h,mi;
 if(m){d=+m[1];mo=months.indexOf(m[2].toLowerCase())+1;y=+m[3];h=+m[4];mi=+m[5];if(m[6])h=h%12+(m[6].toUpperCase()==='PM'?12:0);}
 else {m=s.match(/(\d{4})\s*[年/-]\s*(\d{1,2})\s*[月/-]\s*(\d{1,2})\s*日?.*?(\d{1,2}):(\d{2})/);if(!m)return null;[y,mo,d,h,mi]=m.slice(1).map(Number);if(/下午/.test(s)&&h<12)h+=12;if(/上午/.test(s)&&h===12)h=0;}
 if(mo<1||mo>12||d<1||d>31||h>23||mi>59)return null;
 const n=Date.UTC(y,mo-1,d,h-8,mi)/1000, c=new Date(n*1000+8*3600000);
 return c.getUTCFullYear()===y&&c.getUTCMonth()===mo-1&&c.getUTCDate()===d?n:null;
};

const readMoodleActivity = (doc, kind) => {
 let due=null,opened=null,status='unknown',recognized=false;
 for(const row of doc.querySelectorAll('.submissionstatustable tr')){
  const cells=[...row.children];if(cells.length<2)continue;
  const key=activityClean(cells[0].textContent),value=activityClean(cells[1].textContent);
  if(/^(Due date|截止日期|到期日|截止时间)$/i.test(key))due=parseDate(value);
  if(/^(Submission status|提交状态)$/i.test(key)){
   recognized=true;
   if(/^(submitted for grading|已提交.*评|已提交评分)$/i.test(value))status='submitted';
   else if(/draft|草稿/i.test(value))status='draft';
   else if(/no attempt|no submission|not submitted|未尝试|未提交|尚未提交|尚未尝试/i.test(value))status='notSubmitted';
  }
 }
 if(kind==='quiz'){
  const table=doc.querySelector('table.quizattemptsummary');
  if(table){
   const headers=[...table.querySelectorAll('thead th')];
   const stateIndex=headers.findIndex(h=>/^(State|Status|状态|作答状态|测验状态)$/i.test(activityClean(h.textContent)));
   const states=[];
   if(stateIndex>=0)for(const row of table.querySelectorAll('tbody tr')){
    const cell=row.children[stateIndex];if(!cell)continue;
    const clone=cell.cloneNode(true);clone.querySelectorAll('.statedetails').forEach(n=>n.remove());
    states.push(activityClean(clone.textContent));
   }
   // A finished attempt satisfies the work unless a new attempt remains active.
   // Never infer completion from a grade, a Review link or a start button.
   if(states.some(t=>/^(In progress|Overdue|进行中|正在进行|超时|逾期未提交)$/i.test(t))){status='draft';recognized=true;}
   else if(states.some(t=>/^(Finished|Completed|已完成|完成|已结束|结束)$/i.test(t))){status='submitted';recognized=true;}
   else if(states.some(t=>/^(Never submitted|Abandoned|从未提交|未提交|已放弃)$/i.test(t))){status='notSubmitted';recognized=true;}
  }
  for(const el of doc.querySelectorAll('.quizinfo p,.quizinfo li')){
   const text=activityClean(el.textContent);
   if(/quiz (?:will )?close|quiz closed|截止|关闭|结束于/i.test(text))due=parseDate(text)??due;
   if(/quiz opened|available from|will open|开放|开始于/i.test(text))opened=parseDate(text)??opened;
  }
 }
 for(const el of doc.querySelectorAll('[data-region="activity-dates"] [data-timestamp]')){
  const t=Number(el.getAttribute('data-timestamp')),label=activityClean(el.parentElement?.textContent);
  if(t>0&&/due|close|截止|到期|关闭/i.test(label))due=t;
  if(t>0&&/open|opened|开放|开始/i.test(label))opened=t;
 }
 return {due,opened,status,recognized};
};
