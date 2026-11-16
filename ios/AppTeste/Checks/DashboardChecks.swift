// Run: cat Sources/AppTeste/DashboardData.swift Checks/DashboardChecks.swift | swift -
let fixture = #"""
{"db":{"os":[
  {"status":"Entregue","dataEntrada":"2026-10-01","dataEntrega":"2026-11-15","total":100},
  {"status":"Entregue","dataEntrada":"2026-11-15","dataEntrega":"","total":25},
  {"status":"Concluído","dataEntrada":"2026-11-15","total":900},
  {"status":"Em reparo","prazo":"2000-01-01"}
],"vendas":[
  {"status":"Concluída","data":"2026-11-15T12:00:00","total":50},
  {"status":"Cancelada","data":"2026-11-15","total":500},
  {"status":"Concluída","data":"2026-11-01","total":20}
],"orcamentos":[{"status":"Pendente","total":45},{"status":"Aprovado","total":500}],
"produtos":[{"controla":true,"estoque":0,"estoqueMin":0},{"controla":false,"estoque":0},{"controla":true,"estoque":3,"estoqueMin":2}]}}
"""#
let dashboard = try JSONDecoder().decode(DashboardSnapshot.self, from: Data(fixture.utf8)).db
precondition(dashboard.revenue(prefix: "2026-11-15") == 175, "Revenue must exclude unfinished orders and cancelled sales, and use delivery dates")
precondition(dashboard.revenue(prefix: "2026-11") == 195)
precondition(dashboard.count(["Concluído", "Entregue"]) == 3)
precondition(dashboard.overdue == 1)
precondition(dashboard.lowStock == 1)
precondition(dashboard.pendingQuotes.count == 1)
print("Dashboard checks passed")
