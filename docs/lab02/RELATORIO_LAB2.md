# Relatório - Laboratório 2: Interface Profissional

## 1. Implementações Realizadas

### Funcionalidades Principais

- Interface completa de gerenciamento de tarefas com Material Design 3
- Sistema de CRUD completo (criar, ler, atualizar e deletar tarefas)
- Filtros de visualização: Todas, Pendentes e Concluídas
- Dashboard com estatísticas em tempo real (total, pendentes, concluídas)
- Formulário de criação/edição com validação robusta
- Persistência de dados com SQLite via sqflite
- Estados vazios diferenciados por contexto de filtro
- Feedback visual através de SnackBars coloridos
- Confirmação de exclusão via AlertDialog

### Componentes Material Design 3 Utilizados

- **MaterialApp** com `useMaterial3: true` e tema customizado via `ColorScheme.fromSeed`
- **AppBar** com actions e PopupMenuButton para filtros
- **Card** com elevation, bordas arredondadas e bordas coloridas por prioridade
- **FloatingActionButton.extended** para criação rápida de tarefas
- **TextFormField** com validação e prefixIcon
- **DropdownButtonFormField** para seleção de prioridade
- **SwitchListTile** para toggle de tarefa completa
- **ElevatedButton** e **OutlinedButton** com styling customizado
- **SnackBar** para notificações de sucesso/erro
- **AlertDialog** para confirmações
- **RefreshIndicator** para pull-to-refresh
- **LinearGradient** no card de estatísticas
- **InkWell** para feedback tátil nos cards

## 2. Desafios Encontrados

### Dificuldades Principais

- **Configuração do Material Design 3**: Inicialmente tive dificuldade para entender a migração completa do Material 2 para Material 3, especialmente no sistema de cores via `ColorScheme.fromSeed` e customização de temas específicos (CardTheme, InputDecorationTheme).

- **Validação de Formulários**: Implementar validação robusta nos campos (título mínimo de 3 caracteres, campos obrigatórios) exigiu entender o ciclo de vida do `GlobalKey<FormState>` e garantir que a validação ocorresse antes das operações de banco.

- **Gerenciamento de Estado**: Coordenar o estado entre múltiplas telas (TaskListScreen e TaskFormScreen) e garantir que a lista atualize após criar/editar/excluir tarefas foi desafiador. Solucionei usando retorno de valores via `Navigator.pop(context, true)` e verificando o resultado.

### Como Resolvi

- Estudei a documentação oficial do Material 3 e testei diferentes configurações de `ColorScheme` até encontrar uma paleta que funcionasse bem.
- Implementei validação progressiva: primeiro validação visual dos campos, depois validação no momento do submit usando `_formKey.currentState!.validate()`.
- Usei `mounted` checks antes de chamar `setState` e operações assíncronas para evitar erros quando o widget fosse desmontado durante operações de banco.

## 3. Melhorias Implementadas

### Além do Roteiro Básico

- **Card de Estatísticas com Gradiente**: Implementei um card visualmente atraente com gradiente azul exibindo estatísticas em tempo real (total, pendentes, concluídas) com ícones e tipografia hierárquica.

- **Badges de Prioridade Coloridos**: Cada tarefa exibe um badge colorido com ícone representando sua prioridade (Baixa=verde, Média=laranja, Alta=vermelho, Urgente=roxo), facilitando identificação visual rápida.

- **Empty States Contextuais**: Diferentes mensagens e ícones para estados vazios dependendo do filtro ativo (todos, pendentes, concluídas), melhorando a UX.

- **Bordas Coloridas nos Cards**: Cards de tarefas têm bordas coloridas baseadas na prioridade, criando hierarquia visual clara.

- **Validação Avançada**: Validação de título mínimo de 3 caracteres, limite de caracteres com contadores visuais, e feedback imediato.

- **Feedback Visual Rico**: SnackBars com cores semânticas (verde=sucesso, azul=atualização, vermelho=erro) e mensagens descritivas.

- **Switch com Subtitle Dinâmico**: O SwitchListTile no formulário mostra subtítulo diferente dependendo do estado (completa/pendente).

## 4. Aprendizados

### Principais Conceitos

- **Material Design 3**: Compreendi a evolução do design system, especialmente o novo sistema de cores baseado em seeds, que gera paletas harmoniosas automaticamente. O `ColorScheme.fromSeed` substitui a necessidade de definir cores manualmente.

- **Temas Customizados**: Aprendi a customizar temas específicos (CardTheme, InputDecorationTheme) dentro do ThemeData principal, mantendo consistência visual em toda a aplicação.

- **Componentes Compostos**: Criei widgets reutilizáveis (TaskCard) seguindo boas práticas de composição, facilitando manutenção e testabilidade.

- **Gerenciamento de Estado em Múltiplas Telas**: Entendi como coordenar estado entre telas usando callbacks, Navigator com valores de retorno e verificações de `mounted` para evitar memory leaks.

- **Padrão Singleton**: Aprofundei conhecimento sobre o padrão Singleton no DatabaseService, garantindo uma única instância de conexão com o banco.

### Diferenças entre Lab 1 e Lab 2

- **Lab 1**: Foco em estrutura básica, CRUD simples, lista básica sem filtros. Interface funcional mas não polida.
- **Lab 2**: Evolução para interface profissional com Material 3, filtros, estatísticas, validações robustas, feedback visual rico e componentes customizados. A experiência do usuário foi significativamente melhorada.

## 5. Próximos Passos

### Funcionalidades a Adicionar

- **Sistema de Busca**: Implementar barra de pesquisa para filtrar tarefas por título ou descrição em tempo real.
- **Notificações Push**: Alertas para tarefas com data de vencimento próxima ou vencidas.
- **Ordenação**: Permitir ordenar tarefas por data de criação, prioridade, data de vencimento ou título.
- **Seletor de Data**: Implementar DatePicker para definir e exibir data de vencimento nas tarefas (já há suporte no modelo Task, falta UI).
- **Modo Escuro**: Adicionar suporte a tema claro/escuro com toggle no AppBar.

### Ideias para Melhorar

- **Categorias/Etiquetas**: Sistema de categorização de tarefas com tags coloridas.
- **Arquivamento**: Permitir arquivar tarefas concluídas sem deletá-las permanentemente.
- **Exportação**: Exportar lista de tarefas para PDF ou CSV.
- **Animações**: Adicionar animações suaves para transições entre telas e operações CRUD.
- **Localização**: Suporte a múltiplos idiomas usando `intl` package (já incluído no pubspec.yaml).
- **Sincronização em Nuvem**: Integração com Firebase para sincronizar tarefas entre dispositivos.
