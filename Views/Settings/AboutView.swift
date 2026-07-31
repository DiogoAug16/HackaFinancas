import Foundation
import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleVersion"
        ) as? String ?? "1"
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                appIdentity

                projectCard

                aboutCard(
                    title: "Nossa proposta",
                    symbol: "heart.fill"
                ) {
                    Text(
                        "Entender seu dinheiro e o valor real das suas compras deve ser simples. O Controle Gastos une entradas, despesas, tempo de uso e vida útil para transformar seu histórico em escolhas mais conscientes."
                    )
                }

                aboutCard(
                    title: "Privacidade",
                    symbol: "lock.shield.fill"
                ) {
                    Text(
                        "Despesas, entradas, itens e registros de uso ficam armazenados localmente neste aparelho. Nesta versão, nada desse histórico é enviado a serviços externos."
                    )
                }

                aboutCard(
                    title: "Tecnologia",
                    symbol: "swift"
                ) {
                    Text(
                        "Desenvolvido para iPhone com SwiftUI e SwiftData."
                    )
                }

                versionCard
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .background(
            AppStyle.background(colorScheme)
                .ignoresSafeArea()
        )
        .navigationTitle("Sobre")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appIdentity: some View {
        VStack(spacing: 12) {
            BrandLogo(
                variant: .playful,
                size: 132
            )

            VStack(spacing: 4) {
                Text("Controle Gastos")
                    .font(
                        .system(
                            .title,
                            design: .rounded,
                            weight: .semibold
                        )
                    )

                Text("seu dinheiro e suas escolhas, mais claros")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .accessibilityElement(
            children: .combine
        )
    }

    private var projectCard: some View {
        aboutCard(
            title: "Projeto",
            symbol: "graduationcap.fill"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HackaTruckLogo()
                    .frame(maxWidth: .infinity)

                Text(
                    "Projeto para o HackaTruck - Maker Space, desenvolvido por alunos do curso de Sistemas de Informação da Universidade Federal de Mato Grosso (UFMT)."
                )
            }
        }
    }

    private var versionCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "app.badge.fill")
                .font(.subheadline.bold())
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .accessibilityHidden(true)
                .frame(width: 38, height: 38)
                .background(
                    AppStyle.mint.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 11,
                        style: .continuous
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Versão \(version)")
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )

                Text("Build \(build)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .appCard(
            colorScheme: colorScheme
        )
        .accessibilityElement(
            children: .combine
        )
    }

    private func aboutCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(
                        AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .accessibilityHidden(true)

                Text(title)
                    .font(.headline)
            }

            content()
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .appCard(
            colorScheme: colorScheme
        )
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
