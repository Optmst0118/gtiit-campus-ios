// Read only the Dashboard's exam component, including its pre-pagination memo.
// Never enumerate the application store, profile, grade objects or credentials.
return (() => {
  if (location.protocol !== 'https:' || location.hostname !== 'students.gtiit.edu.cn') return JSON.stringify({state:'login'});
  if (location.pathname !== '/') return JSON.stringify({state:'wrongPage'});
  const section = document.getElementById('Exams');
  if (!section) return JSON.stringify({state:document.querySelector('input[type="password"]') ? 'login' : 'loading'});
  const clean = v => typeof v === 'string' || typeof v === 'number' ? String(v).trim().slice(0,240) : '';
  let rows = null;
  const valid = a => Array.isArray(a) && a.length > 0 && a.length <= 500 && a.every(x => x && typeof x === 'object' && 'courseCode' in x && 'examSession' in x && 'date' in x && 'time' in x);
  const key = Object.keys(section).find(k => k.startsWith('__reactFiber$'));
  let fiber = key ? section[key] : null;
  for (let depth=0; fiber && depth<8; depth++, fiber=fiber.return) {
    let hook = fiber.memoizedState;
    for (let i=0; hook && i<40; i++, hook=hook.next) {
      const memo = hook.memoizedState;
      // useMemo stores [value, dependencies]. Do not traverse arbitrary objects.
      if (Array.isArray(memo) && valid(memo[0]) && (!rows || memo[0].length>rows.length)) rows=memo[0];
    }
  }
  if (!rows) {
    if (/Scheduled exams in the current semester will appear here/i.test(section.textContent)) rows=[];
    else return JSON.stringify({state:'loading'});
  }
  const items = rows.map(x => ({course:clean(x.courseName),code:clean(x.courseCode),session:clean(x.examSession),date:clean(x.date).slice(0,10),time:clean(x.time).slice(0,5),duration:Number(x.duration)||0,venue:Array.isArray(x.venues)?x.venues.map(v=>clean(v.classNumber)).filter(Boolean).join(' · '):''}));
  if (items.some(x=>!x.course || !/^\d{4}-\d{2}-\d{2}$/.test(x.date) || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x.time))) return JSON.stringify({state:'changed'});
  const semester=Array.from(document.querySelectorAll('select')).map(s=>s.selectedOptions?.[0]?.textContent||'').find(s=>/^\d{4}-\d{2}\s+(WINTER|SPRING|SUMMER)/i.test(s.trim()));
  if (!semester) return JSON.stringify({state:'loading'});
  return JSON.stringify({state:'ready',semester:clean(semester),items});
})();
