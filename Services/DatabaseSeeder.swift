import Foundation
import SwiftData

final class DatabaseSeeder {
    static let shared = DatabaseSeeder()

    private init() {}

    func seedSampleData(modelContext: ModelContext, clearExisting: Bool = false) {
        if clearExisting {
            try? modelContext.delete(model: Expense.self)
            try? modelContext.delete(model: IncomeEntry.self)
            try? modelContext.delete(model: TrackedItem.self)
            try? modelContext.delete(model: UsageRecord.self)
        }

        let calendar = Calendar.current
        let now = Date.now

        // Helper to construct dates relative to current month
        func date(monthsAgo: Int, day: Int) -> Date {
            var comp = calendar.dateComponents([.year, .month], from: now)
            comp.month = (comp.month ?? 1) - monthsAgo
            comp.day = day
            return calendar.date(from: comp) ?? now
        }

        // ----------------------------------------------------
        // 1. INCOMES (Salários e Rendas)
        // ----------------------------------------------------
        let incomes: [(title: String, cents: Int, monthsAgo: Int, day: Int, cat: IncomeCategory, rec: FinancialRecurrence)] = [
            ("Salário Mensal", 550000, 0, 5, .salary, .monthly),
            ("Salário Mensal", 550000, 1, 5, .salary, .monthly),
            ("Salário Mensal", 550000, 2, 5, .salary, .monthly),
            ("Salário Mensal", 550000, 3, 5, .salary, .monthly),
            ("Projeto Freelance Design", 120000, 0, 15, .extra, .once),
            ("Projeto Freelance Web", 180000, 1, 20, .freelance, .once),
            ("Reembolso de Viagem", 45000, 2, 10, .refunds, .once),
            ("Rendimento de Investimentos", 32000, 0, 28, .investments, .monthly),
            ("Rendimento de Investimentos", 31000, 1, 28, .investments, .monthly)
        ]

        for inc in incomes {
            let entry = IncomeEntry(
                title: inc.title,
                amountInCents: inc.cents,
                date: date(monthsAgo: inc.monthsAgo, day: inc.day),
                category: inc.cat,
                notes: "Lançamento de teste gerado pelo Seeder.",
                recurrence: inc.rec
            )
            modelContext.insert(entry)
        }

        // ----------------------------------------------------
        // 2. EXPENSES (Despesas Variadas nos últimos meses)
        // ----------------------------------------------------
        let expenseTemplates: [(title: String, cents: Int, monthsAgo: Int, day: Int, cat: ExpenseCategory, rec: FinancialRecurrence, notes: String)] = [
            // Mês Atual (0)
            ("Supermercado Big", 64580, 0, 2, .food, .once, "Compras do mês"),
            ("Aluguel do Apartamento", 180000, 0, 5, .home, .monthly, "Aluguel mensal com condomínio"),
            ("Conta de Luz Energisa", 24530, 0, 10, .home, .monthly, "Energia elétrica"),
            ("Posto de Gasolina Shell", 22000, 0, 12, .transport, .once, "Abastecimento do carro"),
            ("Restaurante Outback", 18500, 0, 14, .food, .once, "Jantar de fim de semana"),
            ("Farmácia Droga Raia", 9450, 0, 16, .health, .once, "Medicamentos"),
            ("Assinatura Netflix & Spotify", 6990, 0, 18, .subscriptions, .monthly, "Mensalidade serviços de streaming"),
            ("Curso Online de Swift", 29900, 0, 20, .education, .once, "Treinamento HackaTruck"),
            ("Supermercado Atacadão", 41200, 0, 22, .food, .once, "Reposição de mantimentos"),
            ("Academia SmartFit", 11990, 0, 25, .health, .monthly, "Plano mensal treino"),

            // Mês Anterior (1)
            ("Supermercado Big", 58000, 1, 3, .food, .once, "Compras quinzenais"),
            ("Aluguel do Apartamento", 180000, 1, 5, .home, .monthly, "Aluguel mensal"),
            ("Conta de Luz Energisa", 21000, 1, 10, .home, .monthly, "Energia elétrica"),
            ("Cinema com Pipoca", 7500, 1, 11, .leisure, .once, "Lazer fim de semana"),
            ("Posto de Gasolina Shell", 20000, 1, 15, .transport, .once, "Gasolina"),
            ("Jantar Pizzaria", 12000, 1, 18, .food, .once, "Pizza com amigos"),
            ("Assinatura Netflix & Spotify", 6990, 1, 18, .subscriptions, .monthly, "Streaming"),
            ("Loja de Roupas Renner", 24000, 1, 22, .clothing, .once, "Roupas para trabalho"),
            ("Academia SmartFit", 11990, 1, 25, .health, .monthly, "Mensalidade academia"),

            // Há 2 Meses (2)
            ("Supermercado Big", 61000, 2, 2, .food, .once, "Compras mensais"),
            ("Aluguel do Apartamento", 180000, 2, 5, .home, .monthly, "Aluguel"),
            ("Conta de Luz Energisa", 23500, 2, 10, .home, .monthly, "Energia"),
            ("Troca de Óleo Mecânica", 35000, 2, 14, .transport, .once, "Revisão automotiva"),
            ("Almoço Restaurante", 8900, 2, 17, .food, .once, "Almoço durante evento"),
            ("Assinatura Netflix & Spotify", 6990, 2, 18, .subscriptions, .monthly, "Streaming"),
            ("Compra Tênis de Corrida", 49990, 2, 21, .clothing, .once, "Tênis esportivo"),
            ("Academia SmartFit", 11990, 2, 25, .health, .monthly, "Academia"),

            // Há 3 Meses (3)
            ("Supermercado Atacadão", 53000, 3, 4, .food, .once, "Mantimentos"),
            ("Aluguel do Apartamento", 180000, 3, 5, .home, .monthly, "Aluguel"),
            ("Conta de Luz Energisa", 19800, 3, 10, .home, .monthly, "Energia elétrica"),
            ("Manutenção Notebook", 15000, 3, 16, .electronics, .once, "Limpeza preventiva"),
            ("Assinatura Netflix & Spotify", 6990, 3, 18, .subscriptions, .monthly, "Streaming"),
            ("Academia SmartFit", 11990, 3, 25, .health, .monthly, "Academia")
        ]

        var createdExpenses: [Expense] = []

        for exp in expenseTemplates {
            let expense = Expense(
                title: exp.title,
                amountInCents: exp.cents,
                date: date(monthsAgo: exp.monthsAgo, day: exp.day),
                category: exp.cat,
                notes: exp.notes,
                recurrence: exp.rec
            )
            modelContext.insert(expense)
            createdExpenses.append(expense)
        }

        // ----------------------------------------------------
        // 3. TRACKED ITEMS & USAGE RECORDS (Consumo Acompanhado)
        // ----------------------------------------------------
        let teniscost = 49990
        let itemTenis = TrackedItem(
            name: "Tênis de Corrida Pro",
            acquisitionValueInCents: teniscost,
            acquiredAt: date(monthsAgo: 2, day: 21),
            category: .clothing,
            notes: "Tênis especial para corrida diária",
            trackingMode: .usage
        )
        modelContext.insert(itemTenis)

        // Add usages for Tênis
        for dayOffset in [20, 18, 15, 12, 10, 8, 5, 2] {
            let useDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            let usage = UsageRecord(
                usedAt: useDate,
                notes: "Corrida matinal de 5km",
                item: itemTenis
            )
            modelContext.insert(usage)
        }

        let itemNotebook = TrackedItem(
            name: "Notebook Workstation",
            acquisitionValueInCents: 650000,
            acquiredAt: date(monthsAgo: 6, day: 1),
            category: .electronics,
            notes: "Computador de desenvolvimento",
            trackingMode: .time
        )
        modelContext.insert(itemNotebook)
        try? modelContext.save()
    }
}
