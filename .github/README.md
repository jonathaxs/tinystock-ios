# <img src="appicons/tinystock-tinted-rounded.png" width="56" align="absmiddle" alt="Ícone do TinyStock">&nbsp;&nbsp;TinyStock&nbsp;<img src="appicons/apple.svg" width="28" height="28" align="absmiddle" alt="Apple">

**[Read in English](#en-tinystock)**

_Organize estoque de produtos, pedidos e vendas do seu pequeno negócio._

O TinyStock foi criado para pequenos negócios feitos à mão, como o crochê da minha mãe e meus produtos impressos em 3D, cujo estoque já não cabia numa planilha.

Cadastre seus produtos com custo de produção e preço. Cada venda vai para um calendário, e os relatórios mostram quantas vendas você fez e quanto lucrou.

Dá para ter mais de uma loja, cada uma com seus produtos, e as notificações avisam o que precisa de atenção.

O app tem o ciclo operacional completo de uma pequena loja: cadastro de produtos com variações, controle de estoque auditável, pedidos de pronta entrega ou sob encomenda, prazos de produção e despacho no calendário e relatórios financeiros por período.

**Em breve na App Store** para iPhone e iPad. A versão para Android já está disponível em [APK](https://jonathasmotta.com/downloads/TinyStock-1.0-beta.apk).

## Funcionalidades - Versão 1.0

**Lojas**
- Várias lojas independentes, com troca rápida entre elas.
- Arquivamento e lixeira com restauração por 30 dias.

**Produtos e estoque**
- Produtos com foto, preço de venda, custo e lucro por unidade.
- Variações opcionais (cor, tamanho, modelo), cada uma com seu próprio saldo.
- Toda alteração de estoque gera uma movimentação registrada, o que permite auditar entradas, saídas e ajustes.

**Pedidos**
- Pedidos de pronta entrega ou para produção.
- Canais de venda: venda direta, Shopee, Mercado Livre ou outro canal personalizado, com cálculo de taxas.
- Fluxo de status: novo, aguardando produção, em produção, pronto para envio, enviado, concluído ou cancelado.
- Baixa automática do estoque e registro do retrato financeiro de cada pedido (preço, custo e taxa no momento da venda).

**Calendário e lembretes**
- Calendário interno com prazos de produção e despacho, filtros e atalhos.
- Notificações locais de produção e despacho.
- Exportação dos compromissos para o app Calendário do iPhone.

**Relatórios**
- Receita, custos, taxas e lucro líquido por loja e período.
- Desempenho por canal de venda e produtos mais vendidos.

**Dados e personalização**
- Sincronização automática e privada pelo iCloud (CloudKit).
- Backup em JSON para exportar e importar, compatível com a versão Android, além de cópia manual no iCloud Drive.
- Cores de destaque configuráveis.
- Interface em Português do Brasil e English, conforme o idioma do iPhone.
- Suporte a VoiceOver, Dynamic Type, modo claro e modo escuro.

## Arquitetura

```mermaid
flowchart LR
    subgraph App["TinyStock (app iOS)"]
        Views["Views SwiftUI"]
        Notif["Notificações e integração com o Calendário"]
    end

    subgraph Core["TinyStockCore (Swift Package)"]
        Models["Models SwiftData"]
        Services["Serviços e regras de negócio"]
        Loc["Localização en / pt-BR"]
    end

    Views --> Services
    Notif --> Services
    Services --> Models
    Models --> Store[("SwiftData")]
    Store <--> CloudKit[("iCloud privado")]
    Services --> Backup["Backup JSON e iCloud Drive"]
```

- **SwiftUI** para toda a interface, com **Liquid Glass** no iOS 26 ou superior e o visual padrão do sistema no iOS 18.
- Uma tela Início com o resumo da loja e o catálogo. Relatórios e Calendário abrem por cima dela, e os Ajustes como página, por um roteador único (`AppRouter`).
- Layout adaptado ao iPad e ao iPhone dobrável, com a lista ao lado do conteúdo.
- **SwiftData** para persistência local, com sincronização pelo **CloudKit** em banco privado do usuário.
- **TinyStockCore**: Swift Package local que concentra models, regras de negócio, serviços, localização e testes. O app fica responsável apenas pela interface e pela integração com o sistema, o que mantém o Core testável e reutilizável em futuras extensões, como widgets.
- **Decimal** em todos os valores monetários, evitando erros de arredondamento.
- **Swift Testing** para os testes automatizados do Core.
- Nenhuma dependência externa: apenas frameworks nativos da Apple.

## Estrutura do repositório

```text
TinyStock/
├── TinyStock/                 App iOS
│   ├── Navigation/            Roteador: páginas, sheets e pedidos vindos das notificações
│   ├── Views/                 Telas por área: Início, Produtos, Calendário, Relatórios, Ajustes e boas-vindas
│   ├── Notifications/         Lembretes locais e navegação a partir das notificações
│   └── Resources/             Info.plist e textos do sistema localizados
├── TinyStockCore/             Swift Package com o domínio do app
│   ├── Sources/TinyStockCore/
│   │   ├── Models/            Lojas, produtos, variações, estoque e pedidos
│   │   ├── Services/          Regras de estoque, pedidos, relatórios, lembretes e backup
│   │   ├── Persistence/       Configuração do SwiftData e do CloudKit
│   │   ├── Formatting/        Formatação de moeda
│   │   ├── Images/            Tratamento das fotos dos produtos
│   │   └── Resources/         Localização en e pt-BR
│   └── Tests/                 Testes automatizados do Core
└── TinyStock.xcodeproj
```

## Requisitos

- iOS 18 ou superior (o Liquid Glass aparece a partir do iOS 26).
- Xcode 27 ou superior.
- Swift 6.

Para executar em um iPhone com sincronização, selecione o seu Team e configure o container do iCloud em **Signing & Capabilities**.

## Privacidade

O TinyStock não exige cadastro e não envia dados ao desenvolvedor. As informações ficam no próprio dispositivo e, quando a sincronização está ativa, na conta privada do iCloud do usuário. Não há servidores próprios, ferramentas de análise ou anúncios.

## Android

Existe também uma versão nativa para Android, feita em Kotlin e Jetpack Compose: [tinystock-android](https://github.com/jonathaxs/tinystock-android).

## Autor

Desenvolvido por **Jonathas Motta** ([@jonathaxs](https://github.com/jonathaxs)).

---

# <img src="appicons/tinystock-tinted-rounded.png" width="56" align="absmiddle" alt="TinyStock icon">&nbsp;&nbsp;(EN) TinyStock&nbsp;<img src="appicons/apple.svg" width="28" height="28" align="absmiddle" alt="Apple">

**[Leia em português](#tinystock)**

_Organize product stock, orders and sales for your small business._

TinyStock was created for small handmade businesses, like my mom's crochet and my 3D printed products, whose stock no longer fit in a spreadsheet.

Add your products with their production cost and price. Each sale goes on a calendar, and the reports show how many sales you made and how much profit you earned.

You can have more than one store, each with its own products, and notifications let you know what needs attention.

The app covers the full operating cycle of a small store: a product catalog with variants, auditable stock control, ready-to-ship or made-to-order orders, production and shipping deadlines on the calendar and financial reports by period.

**Coming soon to the App Store** for iPhone and iPad. The Android version is already available as an [APK](https://jonathasmotta.com/downloads/TinyStock-1.0-beta.apk).

## Features - Version 1.0

**Stores**
- Multiple independent stores, with quick switching between them.
- Archive and trash, with restore for 30 days.

**Products and stock**
- Products with a photo, sale price, cost and profit per unit.
- Optional variants (color, size, model), each with its own stock count.
- Every stock change creates a logged movement, so incoming, outgoing and adjustments can be audited.

**Orders**
- Ready-to-ship or made-to-order orders.
- Sales channels: direct sale, Shopee, Mercado Livre or a custom channel, with fee calculation.
- Status flow: new, waiting for production, in production, ready to ship, shipped, completed or canceled.
- Automatic stock deduction and a financial snapshot of each order (price, cost and fee at the time of sale).

**Calendar and reminders**
- Built-in calendar with production and shipping deadlines, filters and shortcuts.
- Local notifications for production and shipping.
- Export of events to the iPhone Calendar app.

**Reports**
- Revenue, costs, fees and net profit by store and period.
- Performance by sales channel and best-selling products.

**Data and personalization**
- Automatic, private sync through iCloud (CloudKit).
- JSON backup to export and import, compatible with the Android version, plus a manual copy to iCloud Drive.
- Configurable accent colors.
- Interface in Brazilian Portuguese and English, following the iPhone's language.
- Support for VoiceOver, Dynamic Type, light mode and dark mode.

## Architecture

```mermaid
flowchart LR
    subgraph App["TinyStock (iOS app)"]
        Views["SwiftUI views"]
        Notif["Notifications and Calendar integration"]
    end

    subgraph Core["TinyStockCore (Swift Package)"]
        Models["SwiftData models"]
        Services["Services and business rules"]
        Loc["Localization en / pt-BR"]
    end

    Views --> Services
    Notif --> Services
    Services --> Models
    Models --> Store[("SwiftData")]
    Store <--> CloudKit[("Private iCloud")]
    Services --> Backup["JSON backup and iCloud Drive"]
```

- **SwiftUI** for the whole interface, with **Liquid Glass** on iOS 26 or later and the standard system look on iOS 18.
- A single Home screen with the store summary and the catalog. Reports and Calendar open on top of it, and Settings as a page, through a single router (`AppRouter`).
- Layout adapted to iPad and to the foldable iPhone, with the list next to the content.
- **SwiftData** for local persistence, synced through **CloudKit** in the user's private database.
- **TinyStockCore**: a local Swift Package that holds the models, business rules, services, localization and tests. The app only handles the interface and system integration, which keeps the Core testable and reusable in future extensions, such as widgets.
- **Decimal** for every money value, avoiding rounding errors.
- **Swift Testing** for the Core's automated tests.
- No external dependencies: only Apple's native frameworks.

## Repository structure

```text
TinyStock/
├── TinyStock/                 iOS app
│   ├── Navigation/            Router: pages, sheets and requests coming from notifications
│   ├── Views/                 Screens by area: Home, Products, Calendar, Reports, Settings and welcome
│   ├── Notifications/         Local reminders and navigation from notifications
│   └── Resources/             Info.plist and localized system strings
├── TinyStockCore/             Swift Package with the app's domain
│   ├── Sources/TinyStockCore/
│   │   ├── Models/            Stores, products, variants, stock and orders
│   │   ├── Services/          Stock, order, report, reminder and backup rules
│   │   ├── Persistence/       SwiftData and CloudKit setup
│   │   ├── Formatting/        Currency formatting
│   │   ├── Images/            Product photo handling
│   │   └── Resources/         en and pt-BR localization
│   └── Tests/                 Core automated tests
└── TinyStock.xcodeproj
```

## Requirements

- iOS 18 or later (Liquid Glass shows up from iOS 26).
- Xcode 27 or later.
- Swift 6.

To run it on an iPhone with sync, select your Team and set up the iCloud container in **Signing & Capabilities**.

## Privacy

TinyStock requires no sign-up and sends no data to the developer. Information stays on the device and, when sync is on, in the user's private iCloud account. There are no servers of its own, no analytics and no ads.

## Android

There is also a native Android version, built with Kotlin and Jetpack Compose: [tinystock-android](https://github.com/jonathaxs/tinystock-android).

## Author

Developed by **Jonathas Motta** ([@jonathaxs](https://github.com/jonathaxs)).
