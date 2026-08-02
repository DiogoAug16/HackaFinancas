# Projeto

<p align="center">
  <img src="./assets/ufmtlogo.png" alt="UFMT" width="110">
  &nbsp;&nbsp;&nbsp;
  <img src="./assets/hacka-logo.png" alt="HackaTruck Maker Space" width="280">
</p>

# Controle Gastos

Aplicativo iOS de finanças pessoais e consumo consciente feito com SwiftUI.
O IBM Cloudant é a fonte principal dos dados.

## Funcionalidades

- Cadastro, edição, busca e exclusão de despesas.
- Cadastro de salários e outras entradas recebidas ou a receber.
- Entradas eventuais, semanais, mensais, trimestrais, semestrais e anuais.
- Saldo real por período, sem contar valores futuros como disponíveis.
- Recebimentos entram no caixa pela data real; pendências permanecem na data prevista.
- Recorrência mensal, trimestral, semestral e anual, com data final.
- Navegação da lista por mês.
- Resumo por mês, semestre ou ano.
- Separação entre valores realizados e lançamentos futuros.
- Cadastro de compras, presentes e bens que o usuário já possui.
- Acompanhamento do custo por dia, semana, mês, ano ou por uso.
- Histórico de uso com data e observação.
- Situações de item em uso, vendido, doado ou descartado, incluindo revenda.
- Vínculo opcional entre uma compra acompanhada e seu único lançamento financeiro.
- Insights de consumo, investimento, itens parados e melhor aproveitamento.
- Representação por ícone da categoria, SF Symbol ou imagem.
- Imagem compartilhada com segurança por despesas e itens vinculados.
- Exclusão de uma ocorrência ou da série completa.
- Edição de uma ocorrência, dos próximos lançamentos ou da série.
- Configurações de aparência, categoria e periodicidade padrão.
- Tela Sobre com informações de versão e privacidade.
- Identidade institucional da UFMT e créditos do HackaTruck Maker Space.
- Suporte aos modos claro e escuro.

## Gerando o projeto

O projeto usa XcodeGen e requer iOS 17 ou posterior.

```sh
xcodegen generate
open HackaFinancas.xcodeproj
```

Os testes podem ser executados pelo scheme `HackaFinancas` no Xcode.

## Dados e imagens

Entradas, despesas, itens e usos são documentos no banco Cloudant
`hackafinancas`. O SwiftData mantém somente uma cópia em memória para as telas.
As imagens são reduzidas antes de seguir com o documento e são reconstituídas
no cache do aparelho.

O vínculo registra a origem financeira do item e impede um segundo
lançamento da mesma compra. Depois do cadastro, gasto e item podem ser
editados de forma independente.

Antes de distribuir uma atualização sobre uma versão já instalada, valide
a migração abrindo no simulador ou aparelho uma base criada pela versão
anterior.

## Gateway para banco não relacional

O serviço [Node-RED](Services/node-red/README.md) faz a ponte entre o app e o
IBM Cloudant. As credenciais ficam somente no ambiente do serviço, nunca no
aplicativo iOS. Em **Configurações > Cloudant**, informe a URL do computador
do laboratório, por exemplo `http://192.168.0.10:1880`, e carregue os dados.

## Inteligência financeira

A integração com IA não está habilitada nesta versão. Ela deve ser feita
por um backend ou serviço móvel protegido, sem chave da API dentro do app.
O contexto enviado deve priorizar totais agregados por período e categoria,
com consentimento explícito para qualquer dado detalhado.

## Projeto

Projeto para o HackaTruck - Maker Space, desenvolvido por alunos do curso
de Sistemas de Informação da Universidade Federal de Mato Grosso (UFMT).
