import WebKit

/// Explicit, one-shot, read-only extraction of the registered portal schedule.
/// No API/token, form values, account identifiers, grades or page HTML are exported.
enum TimetableExtractor {
    struct Result: Decodable {
        let semester: String
        let courses: [Course]
        struct Course: Decodable {
            let name: String; let code: String; let group: String; let weekday: Int
            let start: String; let end: String; let room: String; let building: String
            var local: LocalCourse { LocalCourse(name: name, code: code, group: group, weekday: weekday, start: start, end: end, room: room, building: building) }
        }
    }
    static let script = #"""
    (() => {
      if (location.protocol !== 'https:' || location.hostname !== 'students.gtiit.edu.cn' || !/^\/enrollments\/?$/.test(location.pathname)) throw new Error('OPEN_PORTAL_ENROLLMENTS');
      const clean = v => typeof v === 'string' || typeof v === 'number' ? String(v).trim().slice(0,240) : '';
      let groups = null;
      for (const canvas of document.querySelectorAll('.konvajs-content')) {
        const host = canvas.parentElement;
        const key = Object.keys(host).find(k => k.startsWith('__reactFiber$'));
        let fiber = key ? host[key] : null;
        for (let depth = 0; fiber && depth < 16; depth++, fiber = fiber.return) {
          const candidate = fiber.memoizedProps?.groups;
          if (Array.isArray(candidate) && candidate.length && candidate.every(g => g && 'courseCode' in g && 'startTime' in g && 'day' in g)) { groups = candidate; break; }
        }
        if (groups) break;
      }
      if (!groups) throw new Error('SCHEDULE_NOT_READY');
      const result = [], seen = new Set();
      for (const g of groups.slice(0,500)) {
        if (g.enrolled !== true || g.isPreview || g.postPending || g.deletePending) continue;
        const c = {name:clean(g.courseName),code:clean(g.courseCode),group:clean(g.type)+clean(g.groupId),weekday:Number(g.day),start:clean(g.startTime).slice(0,5),end:clean(g.endTime).slice(0,5),room:clean(g.classNumber),building:clean(g.building)};
        if (!c.name || !/^[0-2]\d:[0-5]\d$/.test(c.start) || !/^[0-2]\d:[0-5]\d$/.test(c.end) || c.weekday<1 || c.weekday>7) throw new Error('SCHEDULE_FORMAT_CHANGED');
        const key = JSON.stringify(c); if (!seen.has(key)) { seen.add(key); result.push(c); }
      }
      if (!result.length) throw new Error('NO_REGISTERED_CLASSES');
      const semester = Array.from(document.querySelectorAll('select')).map(s=>s.selectedOptions?.[0]?.textContent || '').find(s=>/^\d{4}-\d{2}\s+(WINTER|SPRING|SUMMER)/i.test(s.trim())) || '';
      if (!semester) throw new Error('SEMESTER_NOT_READY');
      return JSON.stringify({semester:clean(semester),courses:result});
    })()
    """#
    @MainActor static func extract(from webView: WKWebView) async throws -> Result {
        guard let url = webView.url, url.scheme == "https", url.host == "students.gtiit.edu.cn", url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "enrollments" else { throw ExtractionError.wrongPage }
        let value = try await webView.evaluateJavaScript(script)
        guard let string = value as? String, string.utf8.count < 200_000 else { throw ExtractionError.changed }
        let result = try JSONDecoder().decode(Result.self, from: Data(string.utf8))
        guard !result.courses.isEmpty, result.courses.count <= 300, result.courses.allSatisfy({ $0.local.valid }) else { throw ExtractionError.changed }
        return result
    }
    enum ExtractionError: LocalizedError {
        case wrongPage, changed
        var errorDescription: String? { L10n.tr("请在 App 内打开门户的 Enrollments 周课表，等待课程显示后重试。若页面结构变化，请勿保存不完整课表。") }
    }
}
