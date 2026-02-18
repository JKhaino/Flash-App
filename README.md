# Flash Picker

O `flash_app` é um aplicativo modular desenvolvido em Flutter para a **Flash Engenharia**, projetado para otimizar e agilizar processos de logística e manufatura.

## Visão Geral

O aplicativo atua como um facilitador para o ERP **Protheus**, servindo como uma interface intuitiva para o operador no chão de fábrica. Seu principal objetivo é capturar informações da operação e transmiti-las ao sistema de gestão de forma limpa, padronizada e em tempo real, garantindo a integridade dos dados e a eficiência do processo.

## Funcionalidades

O projeto está organizado com uma arquitetura baseada em funcionalidades, separando as principais responsabilidades do sistema:

*   **Autenticação (`/lib/features/auth`):** Módulo para gerenciamento de acesso de usuários, garantindo que apenas pessoal autorizado possa operar o aplicativo.
*   **Almoxarifado (`/lib/features/almoxarifado`):** Módulo operacional principal.
    *   **Gestão de PMP:** Visão macro das ordens de produção.
    *   **Missões:** Interface de separação e abastecimento para operadores.
    *   **Consulta de Saldo:** Verificação de estoque e endereçamento.
    *   **Engenharia:** Visualização da estrutura de produtos.
*   **Business Intelligence (`/lib/features/bi`):** Dashboards para visualização de indicadores (KPIs) e monitoramento da operação.

## Arquitetura e Tecnologia

*   **Tecnologia Principal:** Flutter e Dart.
*   **Backend:** Supabase (PostgreSQL, Auth, Realtime).
*   **Comunicação:** SDK `supabase_flutter` para integração direta com o banco de dados e serviços de autenticação.
*   **Estrutura do Projeto:**
    *   `/lib/core`: Componentes compartilhados (widgets, modelos, temas).
    *   `/lib/features`: Módulos de negócio (Auth, Almoxarifado, BI).
    *   `/lib/screens`: Telas da interface de usuário.
    *   `/lib/services`: Serviços de aplicação, como comunicação de API.

## Como Começar

Este projeto é um ponto de partida para o desenvolvimento de uma aplicação Flutter.

Para mais informações sobre o desenvolvimento com Flutter, consulte a [documentação online](https://docs.flutter.dev/).

## Estrutura do Banco de Dados

Esta seção apresenta a **Documentação Técnica Oficial** do banco de dados, refletindo a estrutura consolidada com todas as regras de negócio (Separação, Abastecimento, Compliance, Automação e BI).

### 1. 📦 Tabela: `app_produtos`

**Função:** Cadastro Mestre (Dicionário de Dados).  
**Atualização:** Diária (Script Python).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **codigo** (PK) | `VARCHAR(30)` | Código único (Ex: `77.CARRO.X`). |
| **tat** | `VARCHAR(20)` | Chave de ligação com o PMP (Ex: `E295`). **Indexado**. |
| **descricao** | `VARCHAR(200)` | Nome legível do produto. |
| **unidade** | `VARCHAR(6)` | Unidade de medida (PC, KG, UN). |
| **custo_padrao** | `DECIMAL(18,2)` | Custo para validação de assinatura (> R$ 500). |
| **updated_at** | `TIMESTAMP` | Data da última atualização (Automático). |

---

### 2. 🏭 Tabela: `app_pmp`

**Função:** O Gatilho de Produção (Lote).  
**Atualização:** Script Python (Monitoramento PCP) ou Input Manual.  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `SERIAL` | Identificador único do lote (1, 2, 3...). |
| **tat** | `VARCHAR(20)` | Identificador comercial do projeto/carro (Ex: `TAT 11077.05`). |
| **cod_estrutura** | `VARCHAR(30)` | **Vital:** Código Pai da Engenharia (Ex: `77.XXX`). Usado pelo Robô para explodir a lista no Oracle. |
| **qtd_lote** | `INTEGER` | Quantidade a produzir (Multiplicador da lista). |
| **data_entrada** | `TIMESTAMP` | Data que o PMP caiu no sistema. |
| **linha** | `VARCHAR(20)` | Linha de montagem destino (Ex: `LINHA 1`, `DIV`). |
| **status** | `VARCHAR(20)` | Controle de fluxo: `AGUARDANDO`, `MONTADO` (Lista Gerada), `APONTADO` (Finalizado). |
| **qtd_lote_anterior** | `INTEGER` | Histórico para detecção de mudança de quantidade (Versionamento). |
| **flag_recalculo** | `BOOLEAN` | `TRUE` força o Robô a regerar a lista mesmo se nada mudou na engenharia. |

**Índices:**

* `idx_pmp_cod_estrutura` (Para busca rápida no Oracle).

---

### 3. 📚 Tabela: `app_estrutura_simples`

**Função:** Enciclopédia Técnica (Consulta apenas).  
**Atualização:** Full Swap (Apaga e Recria).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `UUID` | Identificador único da linha. |
| **cod_raiz** | `VARCHAR(30)` | Produto Pai Final (Indexado). |
| **cod_pai** | `VARCHAR(30)` | Pai imediato na árvore. |
| **cod_filho** | `VARCHAR(30)` | O componente. |
| **nivel** | `INTEGER` | Nível na hierarquia (1, 2, 3...). |
| **qtd_unitaria** | `DECIMAL(18,6)` | Quantidade técnica por unidade pai. |
| **fix_var** | `VARCHAR(1)` | `F` (Fixo) ou `V` (Variável). |
| **data_adicao** | `DATE` | Quando o item entrou na estrutura. |
| **updated_at** | `TIMESTAMP` | Data da última carga (Automático). |

---

### 4. 📋 Tabela: `app_lista_separacao`

**Função:** O Painel de Controle (Placar Geral).  
**Atualização:** Script Python (Criação) e Triggers (Cálculos Automáticos de Saldo e Status).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `UUID` | Identificador único do item na lista. |
| **id_pmp** (FK) | `INTEGER` | Vínculo com o lote `app_pmp`. |
| **cod_raiz** | `VARCHAR` | Produto final. |
| **produto** | `VARCHAR` | Componente a ser separado. |
| **armazem_destino** | `VARCHAR` | Para onde levar. |
| **tipo_item** | `VARCHAR` | `METALICO`, `COMPRADO`, `FIXADOR`. |
| **qtd_unitaria_eng** | `DECIMAL` | Receita base da engenharia. |
| **qtd_total_calc** | `DECIMAL` | Meta (Receita * Qtd Lote). |
| **qtd_separada** | `DECIMAL` | **Almoxarifado (Físico):** O que está no carrinho (Soma logs de separação). |
| **qtd_transferida** | `DECIMAL` | **Almoxarifado (Fiscal):** O que o Robô baixou no ERP (Logs com Sucesso). |
| **qtd_abastecida** | `DECIMAL` | **Logística (Entrega):** O que chegou na linha (Soma logs de abastecimento). |
| **status_separacao** | `VARCHAR` | **Status Almox:** `AGUARDANDO`, `EM_SEPARACAO`, `CONCLUIDO`. |
| **status_abastecimento** | `VARCHAR` | **Status Logística:** `AGUARDANDO`, `PARCIAL`, `ENTREGUE`. |
| **status_item** | `VARCHAR` | **Status Eng:** `AGUARDANDO`, `NOVO_ENG`, `ALTERADO_ENG`. |
| **cod_engenharia** | `VARCHAR` | Código de referência da engenharia. |
| **updated_at** | `TIMESTAMP` | Data da última alteração (Automático). |

---

### 5. 👥 Tabela: `app_atribuicoes`

**Função:** Escala de Trabalho (Quem faz o que).  
**Atualização:** App (Líder distribui tarefas).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `UUID` | Identificador da atribuição. |
| **id_pmp** (FK) | `INTEGER` | Vínculo com o lote. |
| **user_id** | `UUID` | ID do usuário. |
| **tipo_responsavel** | `VARCHAR(20)` | O que ele vai separar (`METALICO`, etc). |

---

### 6. 🕵️‍♂️ Tabela: `app_log_separacao`

**Função:** Rastreabilidade da Separação (Fila de Integração com ERP).  
**Atualização:** App (Insere Log) e Robô Python (Processa Integração).  

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| **id** (PK) | `UUID` | Identificador único (Gerado Automático). |
| **id_lista** (FK) | `UUID` | **Obrigatório:** Vínculo com a linha da lista original. |
| **user_id** (FK) | `UUID` | **Obrigatório:** Quem separou. |
| **produto** | `VARCHAR` | **Vital (Alternativos):** Código exato do produto físico separado. Essencial quando o operador troca o item original por um similar. |
| **data_hora** | `TIMESTAMP` | Momento exato do Bip (Default: `NOW()`). |
| **qtd_movimentada** | `DECIMAL` | Quanto separou. |
| **tipo_movimento** | `VARCHAR` | **Vital:** `SEPARACAO` (Soma) ou `ESTORNO` (Subtrai). |
| **observacao** | `TEXT` | Justificativa de estorno ou nota do operador. |
| **endereco_retirada_real** | `VARCHAR` | Onde ele realmente pegou a peça (Check de Auditoria). |
| **armazem_destino** | `VARCHAR` | Para onde vai. |
| **status_erp** | `VARCHAR` | **Controle:** `PENDENTE` (Default), `SUCESSO`, `ERRO`. |
| **mensagem_erp** | `TEXT` | Log de retorno do Protheus (em caso de falha). |
| **data_processamento** | `TIMESTAMP` | Quando a integração ocorreu. |

**Triggers:**

* `trg_calcula_separacao` (Alimenta `qtd_separada`, `qtd_transferida` e `status_separacao`).

---

### 7. 📍 Tabela: `app_saldos`

**Função:** Mapa do Tesouro (Onde tem peça).  
**Atualização:** Python (Full Swap a cada 5 min).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **codigo** (PK) | `VARCHAR(30)` | Código do produto. |
| **armazem** (PK) | `VARCHAR(6)` | Código do armazém. |
| **endereco** (PK) | `VARCHAR(15)` | Endereço físico (`A-01-02`). |
| **saldo** | `DECIMAL(18,6)` | Quantidade disponível. |
| **controla_endereco** | `BOOLEAN` | NOVO: TRUE (Exige bipar endereço) / FALSE (Pula). |
| **updated_at** | `TIMESTAMP` | Data da carga (Automático). |

---

### 8. 🚚 Tabela: `app_log_abastecimento`

**Função:** Rastreabilidade da Entrega na Linha (Comprovante).  
**Atualização:** App (No momento da Entrega/Foto).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `UUID` | Identificador único. |
| **id_lista** (FK) | `UUID` | Vínculo com a linha da lista. |
| **user_id** | `UUID` | Quem entregou (Abastecedor). |
| **data_hora** | `TIMESTAMP` | Momento exato. |
| **qtd_entregue** | `DECIMAL` | Quantidade entregue. |
| **tipo_movimento** | `VARCHAR` | `ENTREGA` (Soma) ou `ESTORNO` (Subtrai). Default: `ENTREGA`. |
| **box** | `VARCHAR` | **Novo:** Identificação do Box da linha (Ex: A1, B2). |
| **obs** | `TEXT` | Observações opcionais. |
| **foto_url** | `TEXT` | Link da foto (Supabase Storage). |
| **assinatura_url** | `TEXT` | Link da assinatura (Se Custo > 500). |

**Triggers:**

* `trg_calcula_abastecimento` (Alimenta `qtd_abastecida` e `status_abastecimento`).

---

### 9. 👤 Tabela: `app_usuarios`

**Função:** Central de Identidade, Acesso e Gamificação.  
**Atualização:** Manual (Admin) ou via App.  
**Validação:** Possui Trigger que impede atribuição de cargos inexistentes.  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `UUID` | Identificador único (Deve ser igual ao `User UID` do Auth do Supabase). |
| **username** | `VARCHAR(50)` | **Login Visual:** O crachá do operador (Ex: `joao.silva`). Único e Obrigatório. |
| **email_contato** | `TEXT` | **Recuperação:** E-mail real (pessoal ou do líder) para avisos e recuperação de senha. |
| **nome** | `TEXT` | Nome de exibição no App (Ex: `João Silva`). |
| **funcoes** | `TEXT[]` | **Multi-Papel:** Array de permissões. Ex: `{LIDER_SEP, ADM}`. Validado contra `app_cargos`. |
| **pontos** | `INTEGER` | **Gamificação:** XP acumulado por tarefas realizadas. Default: 0. |
| **nivel** | `INTEGER` | **Gamificação:** Nível do operador. Default: 1. |
| **foto_url** | `TEXT` | Link da foto de perfil (Opcional). |
| **ativo** | `BOOLEAN` | `TRUE` (Acesso liberado) / `FALSE` (Bloqueado). |
| **created_at** | `TIMESTAMP` | Data de criação do cadastro. |

**Índices e Triggers:**

* **Índice Único:** `idx_usuarios_username` (Garante unicidade do login).
* **Trigger:** `trg_check_cargos` (Antes de Insert/Update, executa `validar_cargos_usuario()` para garantir que todos os valores no array `funcoes` existam na tabela `app_cargos`).

---

### 10. 🛂 Tabela: `app_cargos`

**Função:** Dicionário de Permissões e Cargos Oficiais (Lookup Table).  
**Atualização:** Apenas Admin (Raramente muda).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **slug** (PK) | `VARCHAR(30)` | Código interno usado no código e no banco (Ex: `LIDER_SEP`, `SIL_LOVE`). |
| **nome** | `VARCHAR(50)` | Nome legível para exibição nos dropdowns (Ex: `Líder de Separação`). |
| **descricao** | `TEXT` | Explicação técnica do que esse cargo permite fazer. |

**Cargos Oficiais Atuais:**

1. **ADM:** Acesso a Telas Administrativas.
2. **LIDER_SEP:** Líder de Separação.
3. **LIDER_ABA:** Líder de Abastecimento.
4. **SEPARADOR:** Operador de Separação.
5. **ABASTECEDOR:** Operador de Abastecimento.
6. **WATCHDOG:** Monitoramento e Auditoria.
7. **SIL_LOVE:** Acesso Total (Root).

---

### 11. 📊 Tabela: `app_bi_estoque`

**Função:** Tabela consolidada para BI de Estoque (Saldos e Valores).  
**Atualização:** Automática.  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **codigo** (PK) | `VARCHAR(30)` | Código do produto (FK `app_produtos`). |
| **saldo_total** | `DECIMAL(18,6)` | Quantidade total em estoque. |
| **qtd_empenhada** | `DECIMAL(18,6)` | Quantidade reservada/empenhada. |
| **saldo_livre** | `DECIMAL(18,6)` | Quantidade disponível (`Total - Empenhada`). |
| **valor_total** | `DECIMAL(18,2)` | Valor monetário total. |
| **valor_empenho** | `DECIMAL(18,2)` | Valor monetário empenhado. |
| **valor_livre** | `DECIMAL(18,2)` | Valor monetário livre. |
| **updated_at** | `TIMESTAMP` | Data da última atualização. |

**Índices:**

* `idx_bi_valor_total`
* `idx_bi_valor_empenho`
* `idx_bi_saldo_livre`

---

### 12. 📊 View: `view_dashboard_estoque`

**Função:** Vitrine de Dados para o App (JSON Pronto).  
**Lógica:** JOIN entre `app_bi_estoque` e `app_produtos`.  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **codigo** | `VARCHAR` | Código do produto. |
| **descricao** | `VARCHAR` | Nome do Produto. |
| **custo_padrao** | `DECIMAL` | Custo padrão do produto. |
| **saldo_total** | `DECIMAL` | Quantidade total em estoque. |
| **qtd_empenhada** | `DECIMAL` | Quantidade reservada/empenhada. |
| **saldo_livre** | `DECIMAL` | Quantidade disponível. |
| **valor_total** | `DECIMAL` | Valor monetário total. |
| **valor_empenho** | `DECIMAL` | Valor monetário empenhado. |
| **valor_livre** | `DECIMAL` | Valor monetário livre. |
| **updated_at** | `TIMESTAMP` | Data da última atualização. |

---

### 13. ⚡ Funções RPC (Estoque): `get_dashboard_totais()`

**Função:** Executar lógicas complexas ou agregações pesadas no lado do Servidor (Banco de Dados), retornando apenas o resultado leve para o App.  
**Objetivo:** Calcular o somatório financeiro total do estoque (`app_bi_estoque`).  

**Estrutura do Retorno (JSON):**

```json
{
  "total_bruto": 1500000.00,     // Soma de valor_total
  "total_empenhado": 300000.00,  // Soma de valor_empenho
  "total_livre": 1200000.00      // Soma de valor_livre
}

```

---

### 14. 🤝 Tabela: `app_clientes`

**Função:** Cadastro Unificado de Clientes (Dimensão).  
**Objetivo:** Evitar repetição de nomes na tabela de fatos e facilitar a correção de cadastros.  
**Atualização:** Script Python (Upsert - Atualiza se existir, cria se não).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **codigo** (PK) | `VARCHAR(10)` | Código do cliente no ERP (Ex: `001050`). |
| **nome** | `TEXT` | Razão Social ou Nome Fantasia principal. |
| **updated_at** | `TIMESTAMP` | Data da última atualização. |

---

### 15. 💸 Tabela: `app_bi_faturamento`

**Função:** Histórico de Vendas (Data Mart).  
**Atualização:** Script Python (Carga de Movimentação).  
**Índices:** `data_emissao`, `cod_cliente` (Para filtros rápidos no Dashboard).  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** (PK) | `UUID` | Identificador único da transação. |
| **filial** | `VARCHAR(10)` | Filial de origem da venda. |
| **nf** | `VARCHAR(20)` | Número da Nota Fiscal. |
| **serie** | `VARCHAR(5)` | Série da NF (Evita duplicidade de números). |
| **cod_cliente** (FK) | `VARCHAR(10)` | Vínculo com `app_clientes`. |
| **cod_produto** (FK) | `VARCHAR(30)` | Vínculo com `app_produtos`. |
| **data_emissao** | `DATE` | Data do faturamento. |
| **quantidade** | `DECIMAL(18,6)` | Volume vendido (Líquido de devolução). |
| **valor_total** | `DECIMAL(18,2)` | **Receita Líquida:** `(Total - Devolução) - (IPI + ICMS)`. |
| **valor_devolucao** | `DECIMAL(18,2)` | Valor total devolvido. |
| **categoria** | `VARCHAR(20)` | Classificação calculada: `KIT`, `SUCATA`, `ADAPTAÇÃO`. |
| **updated_at** | `TIMESTAMP` | Data da carga. |

---

### 16. 📊 View: `view_dashboard_faturamento`

**Função:** Visão consolidada para o App (JSON Pronto).  
**Lógica:** Faz o JOIN entre `Faturamento`, `Clientes` e `Produtos`.  

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| **id** | `UUID` | Identificador da transação. |
| **filial** | `VARCHAR` | Filial de origem. |
| **nf** | `VARCHAR` | Número da Nota Fiscal. |
| **data_emissao** | `DATE` | Data de emissão. |
| **cod_cliente** | `VARCHAR` | Código do cliente. |
| **nome_cliente** | `TEXT` | Nome do cliente (Lookup). |
| **cod_produto** | `VARCHAR` | Código do produto. |
| **nome_produto** | `VARCHAR` | Descrição do produto (Lookup). |
| **quantidade** | `DECIMAL` | Quantidade vendida. |
| **valor_total** | `DECIMAL` | Faturamento Real. |
| **valor_devolucao** | `DECIMAL` | Valor devolvido. |
| **categoria** | `VARCHAR` | Categoria para filtros. |

---

### 17. ⚡ Funções RPC (Faturamento)

Conjunto de RPCs projetadas para alimentar a tela `FaturamentoScreen`.

#### A. `get_faturamento_mensal()`

**Objetivo:** Retorna o histórico de faturamento agrupado por mês e categoria (Evolução).  
**Retorno:** Tabela (`TABLE`) com colunas: `mes_ano`, `data_sort`, `total`, `categoria`.

#### B. `get_faturamento_cliente_mensal(p_mes, p_ano)`

**Objetivo:** Retorna o ranking de clientes do mês.  
**Retorno:** Tabela (`TABLE`) com colunas: `nome_cliente`, `categoria`, `total`.

#### C. `get_kpis_faturamento_mes(p_mes, p_ano)`

**Objetivo:** Calcular os indicadores macro (Cards do Topo).  
**Retorno:** Objeto Único (`JSON`):

```json
{
  "total_venda": 450000.00,
  "total_devolucao": 12000.00,
  "qtd_notas": 150
}

```

### ⚙️ Funcionalidades Automáticas (Triggers)

**Trigger:** `update_updated_at_column()`
**Aplicada em:** `app_produtos`, `app_estrutura_simples`, `app_lista_separacao`, `app_saldos`.
**Função:** Sempre que houver um `UPDATE` em qualquer linha dessas tabelas, o campo `updated_at` muda para `NOW()` automaticamente.

### ⚡ Automação (Triggers e Funções)

O banco possui duas inteligências ("cérebros") que mantêm a Tabela 4 atualizada:

1. **`atualizar_progresso_separacao()`**
* **Gatilho:** Qualquer insert/update/delete na Tabela 6 (`app_log_separacao`).
* **Ação:**
* Calcula `qtd_separada` (Físico: Soma tudo).
* Calcula `qtd_transferida` (Sistêmico: Soma só status 'SUCESSO').
* Atualiza `status_separacao` (`AGUARDANDO` -> `EM_SEPARACAO` -> `CONCLUIDO`).

2. **`atualizar_progresso_abastecimento()`**
* **Gatilho:** Qualquer insert/update/delete na Tabela 8 (`app_log_abastecimento`).
* **Ação:**
* Calcula `qtd_abastecida` (Soma Entregas - Estornos).
* Atualiza `status_abastecimento` (`AGUARDANDO` -> `PARCIAL` -> `ENTREGUE`).

--

### 18. 🔍 Funções de Busca (Família de Produtos)

Conjunto de funções RPC projetadas para localizar variações de produtos com base na estrutura inteligente do código (Pattern Matching).

#### A. `fn_buscar_familia_sufixo(p_codigo)`

**Objetivo:** Retorna a lista de produtos que compartilham o mesmo radical, ignorando a variação final (remove os 2 últimos dígitos). Útil para buscar itens da mesma linha com pequenas variações.
**Retorno:** Tabela (`SETOF app_produtos`) com todos os campos: `codigo`, `tat`, `descricao`, `unidade`, `custo_padrao`, `updated_at`.

#### B. `fn_buscar_familia_miolo(p_codigo)`

**Objetivo:** Retorna a lista de produtos que possuem o mesmo "núcleo", ignorando o prefixo (2 primeiros dígitos) e o sufixo (4 últimos dígitos). Ideal para localizar o mesmo produto em diferentes filiais ou grupos.
**Retorno:** Tabela (`SETOF app_produtos`) com todos os campos: `codigo`, `tat`, `descricao`, `unidade`, `custo_padrao`, `updated_at`.# app-flash
