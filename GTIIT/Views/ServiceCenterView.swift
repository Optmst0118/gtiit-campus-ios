import SwiftUI
import WebKit

struct ServiceTicket: Identifiable, Decodable, Equatable {
    let id: String
    let title: String
    let group: String
    let owner: String
    let state: String
    let created: String
}

/// Reads only the rendered customer overview in this site's isolated session.
/// Native rows activate the original row, retaining Zammad's routing and forms.
@MainActor enum ServiceCenterDocument {
    static let snapshot = """
    (() => {
        if(location.hostname!=='servicehub.gtiit.edu.cn' || location.hash!=='#ticket/view/my_tickets_as_customer') return null;
        const visible=e=>!!(e.getClientRects().length && getComputedStyle(e).visibility!=='hidden');
        const tables=Array.from(document.querySelectorAll('table')).filter(visible);
        const table=tables.find(t=>/TITLE/i.test(t.innerText)&&/STATE/i.test(t.innerText));
        if(!table) return null;
        const clean=e=>(e?.textContent||'').trim().replace(/\\s+/g,' ');
        const rows=Array.from(table.querySelectorAll('tbody tr')).filter(visible);
        const tickets=rows.flatMap(row=>{
            const c=Array.from(row.querySelectorAll('td'));
            if(c.length<7 || !/^\\d+$/.test(clean(c[1]))) return [];
            return [{id:clean(c[1]),title:clean(c[2]),group:clean(c[3]),owner:clean(c[4]),state:clean(c[5]),created:clean(c[6])}];
        });
        if(rows.some(row=>row.querySelectorAll('td').length>0) && tickets.length!==rows.filter(row=>row.querySelectorAll('td').length>0).length) return null;
        return JSON.stringify(tickets);
    })()
    """
    static func evaluate(_ script: String, in webView: WKWebView) async -> Any? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script, in: nil, in: .defaultClient) { result in
                continuation.resume(returning: try? result.get())
            }
        }
    }
    static func open(_ ticket: ServiceTicket, in webView: WKWebView) async -> Bool {
        guard let data = try? JSONEncoder().encode(ticket.id), let id = String(data: data, encoding: .utf8) else { return false }
        let script = """
        (()=>{
          if(location.hostname!=='servicehub.gtiit.edu.cn'||location.hash!=='#ticket/view/my_tickets_as_customer')return false;
          const rows=Array.from(document.querySelectorAll('table tbody tr'));
          const row=rows.find(r=>r.getClientRects().length&&r.querySelectorAll('td')[1]?.textContent.trim()===\(id));
          if(!row)return false; row.click();return true;
        })()
        """
        return (await evaluate(script, in: webView)) as? Bool ?? false
    }
}

struct ServiceCenterView: View {
    @EnvironmentObject private var app: AppModel
    let url: URL
    var body: some View { ServiceCenterContent(model: app.browser(for: .serviceHub), url: url) }
}

private struct ServiceCenterContent: View {
    @ObservedObject var model: BrowserModel
    let url: URL
    @State private var tickets: [ServiceTicket]?
    @State private var reading = false
    @State private var failedOpen = false
    @State private var pendingDestination: URL?
    @State private var confirmNavigation = false
    var body: some View {
        NativeWebPageView(site: .serviceHub, title: L10n.tr("服务中心"), url: url, hideWebContent: tickets != nil)
            .overlay {
                if let tickets, model.errorText == nil {
                    List {
                        Section(L10n.tr("我的工单")) {
                            if tickets.isEmpty {
                                Text(L10n.tr("暂无工单")).foregroundStyle(.secondary)
                            }
                            ForEach(tickets) { ticket in
                                Button {
                                    Task {
                                        if await ServiceCenterDocument.open(ticket, in: model.webView) { self.tickets = nil }
                                        else { self.tickets = nil; failedOpen = true }
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top) {
                                            Text(ticket.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                            Spacer(minLength: 8)
                                            Text(ticket.state).font(.caption.weight(.medium))
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(Theme.accent.opacity(0.10), in: Capsule())
                                        }
                                        Text(ticket.group).font(.subheadline).foregroundStyle(.secondary)
                                        HStack {
                                            Text(verbatim: "#" + ticket.id)
                                            Spacer()
                                            Text(ticket.created)
                                        }.font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 5)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden).background(Theme.pageBackground)
                    .refreshable { self.tickets = nil; model.reload() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L10n.tr("我的工单"), systemImage: "tray") { go(SiteID.serviceHub.homeURL) }
                        Button(L10n.tr("新建工单"), systemImage: "square.and.pencil") {
                            go(URL(string: "https://servicehub.gtiit.edu.cn/#customer_ticket_new")!)
                        }
                        Button(L10n.tr("知识库"), systemImage: "books.vertical") {
                            go(URL(string: "https://servicehub.gtiit.edu.cn/#knowledge_base")!)
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease") }
                    .accessibilityLabel(L10n.tr("服务中心导航"))
                }
            }
            .task {
                while !Task.isCancelled {
                    await readDocument()
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                }
            }
            .onDisappear { tickets = nil }
            .confirmationDialog(L10n.tr("离开此页面？"), isPresented: $confirmNavigation, titleVisibility: .visible) {
                Button(L10n.tr("离开"), role: .destructive) {
                    if let destination = pendingDestination { tickets = nil; model.load(destination) }
                    pendingDestination = nil
                }
                Button(L10n.tr("继续编辑"), role: .cancel) { pendingDestination = nil }
            }
            .alert(L10n.tr("请在页面中选择工单"), isPresented: $failedOpen) { Button(L10n.tr("完成"), role: .cancel) {} }
    }
    private func go(_ url: URL) {
        if model.hasUnsavedChanges { pendingDestination = url; confirmNavigation = true }
        else { tickets = nil; model.load(url) }
    }
    @MainActor private func readDocument() async {
        guard !reading else { return }
        reading = true; defer { reading = false }
        guard !model.isLoading, model.errorText == nil,
              let value = await ServiceCenterDocument.evaluate(ServiceCenterDocument.snapshot, in: model.webView),
              let json = value as? String, let data = json.data(using: .utf8), data.count < 1_000_000,
              let rows = try? JSONDecoder().decode([ServiceTicket].self, from: data) else { tickets = nil; return }
        if tickets != rows { tickets = rows }
    }
}
