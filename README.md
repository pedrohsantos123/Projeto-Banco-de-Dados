# Bloco de Notas

Aplicativo de bloco de notas feito em **Flutter** que guarda as notas no aparelho (**SQLite**) e na nuvem (**Cloud Firestore**), com login por e-mail e senha, categorias, pesquisa e lixeira com recuperação.

## Sumário
1. [Funcionalidades](#1-funcionalidades)
2. [Tecnologias e dependências](#2-tecnologias-e-dependências)
3. [Como instalar e executar](#3-como-instalar-e-executar)
4. [Configuração do Firebase](#4-configuração-do-firebase)
5. [Arquitetura e organização dos arquivos](#5-arquitetura-e-organização-dos-arquivos)
6. [Padrões de projeto](#6-padrões-de-projeto)
7. [Armazenamento local e integração com o Firebase](#7-armazenamento-local-e-integração-com-o-firebase)
8. [Estratégia de sincronização e tratamento de erros](#8-estratégia-de-sincronização-e-tratamento-de-erros)
9. [Autenticação e segurança dos dados](#9-autenticação-e-segurança-dos-dados)
10. [Descrição do que foi desenvolvido](#10-descrição-do-que-foi-desenvolvido)
11. [Capturas de tela](#11-capturas-de-tela)
12. [Fluxo Git utilizado](#12-fluxo-git-utilizado)

---

## 1. Funcionalidades

**Requisitos obrigatórios**
- Cadastrar, consultar, editar e excluir notas, no banco local e no Firebase.
- Login e cadastro com Firebase Authentication; cada nota fica associada ao usuário (`userId`).
- Recuperação das notas da nuvem ao entrar de novo ou em outra instalação.
- Categorias (Estudos, Trabalho, Pessoal e categorias criadas pelo usuário), com filtro na lista.
- Pesquisa por título ou conteúdo, com resultados na própria lista.
- Tratamento de erros de conexão: o app continua funcionando offline e avisa o usuário.
- Regras de segurança do Firestore: um usuário não vê nem altera notas de outro.

**Funcionalidade adicional: lixeira com recuperação**
- Ao excluir, a nota vai para a lixeira (continua guardada, local e na nuvem).
- Na lixeira é possível **restaurar** a nota ou **excluí-la definitivamente**.
- A exclusão definitiva remove a nota do SQLite e do Firestore.

**Indicador de sincronização:** cada nota mostra uma nuvem verde (sincronizada) ou cinza (pendente de envio).

## 2. Tecnologias e dependências

| Tecnologia | Uso |
|---|---|
| Flutter / Dart | Interface e lógica |
| `sqflite` | Banco de dados local (SQLite) |
| `sqflite_common_ffi_web` | SQLite no navegador (execução no Chrome) |
| `firebase_core` | Inicialização do Firebase |
| `firebase_auth` | Login por e-mail e senha |
| `cloud_firestore` | Armazenamento das notas na nuvem |
| `path` | Caminho do arquivo do banco |
| `uuid` | Geração de IDs únicos das notas |

## 3. Como instalar e executar

**Pré-requisitos:** Flutter instalado, Node.js (para a CLI do Firebase) e, no Windows, o **Modo de Desenvolvedor** ativado (`start ms-settings:developers`).

```bash
git clone <URL-DO-REPOSITORIO>
cd bloco_de_nota_turma_A
flutter pub get
```

Configure o Firebase (seção 4) e rode:

```bash
flutter run -d chrome      # navegador
flutter run -d windows     # desktop Windows (requer Visual Studio com C++)
flutter run                # Android (emulador ou celular)
```

**Somente para executar no Chrome**, é necessário gerar os arquivos do SQLite para web (uma vez):

```bash
dart run sqflite_common_ffi_web:setup
```

Isso cria `sqflite_sw.js` e `sqlite3.wasm` na pasta `web/`. No `main.dart` o app já seleciona esse banco quando roda na web:

```dart
if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
```

> No PowerShell, se o `npm` for bloqueado, use `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` na mesma janela.

## 4. Configuração do Firebase

As credenciais **não estão no repositório**. Cada pessoa gera as suas:

1. Em [console.firebase.google.com](https://console.firebase.google.com) crie um projeto.
2. **Authentication → Método de login → E-mail/senha**: ative.
3. **Firestore Database → Criar banco de dados**.
4. Aba **Regras**: cole o conteúdo do arquivo `firestore.rules` deste repositório e publique.
5. No terminal, na pasta do projeto:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Escolha o projeto e marque as plataformas (web, windows, android). Isso gera `lib/firebase_options.dart`.

Arquivos de credenciais ignorados pelo Git (`.gitignore`):
```
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

## 5. Arquitetura e organização dos arquivos

```
lib/
├── main.dart                      Inicializa Firebase e SQLite; decide entre login e notas
├── models/
│   └── note.dart                  Classe Note (conversão para SQLite e Firestore)
├── data/
│   ├── local_db.dart              Acesso ao SQLite (tabela notes, consultas, pesquisa)
│   ├── remote_repository.dart     Acesso ao Firestore (coleção notes)
│   └── note_repository.dart       Regras de negócio e sincronização
├── services/
│   └── auth_service.dart          Firebase Authentication
└── screens/
    ├── login_screen.dart          Login e criação de conta
    ├── notes_screen.dart          Lista, categorias, pesquisa, lixeira, sincronização
    └── note_edit_screen.dart      Criar e editar nota, nova categoria
firestore.rules                    Regras de segurança do Firestore
```

A interface só conversa com `NoteRepository`. Ela não acessa SQLite nem Firestore diretamente.

## 6. Padrões de projeto

- **Repository (`NoteRepository`)**: concentra a decisão de onde ler e gravar. As telas chamam `save`, `list`, `moveToTrash`, `restore` e `sync` sem saber se o dado vem do SQLite ou do Firestore. Foi usado para manter a lógica de sincronização em um único lugar e facilitar manutenção e testes.
- **Singleton (`LocalDb.instance`)**: garante uma única conexão aberta com o SQLite, evitando conflitos de acesso ao arquivo.
- **Separação em camadas (apresentação, dados e serviços)**: telas em `screens/`, acesso a dados em `data/`, autenticação em `services/`. Cada camada tem uma responsabilidade.
- **Observer (`authStateChanges` com `StreamBuilder`)**: em `main.dart`, a tela troca sozinha entre login e lista de notas quando o usuário entra ou sai.

## 7. Armazenamento local e integração com o Firebase

**SQLite** — tabela `notes`:

| Coluna | Descrição |
|---|---|
| `id` | UUID da nota (mesmo ID no Firestore) |
| `user_id` | UID do usuário autenticado |
| `title`, `content`, `category` | Dados da nota |
| `created_at`, `updated_at` | Datas em milissegundos |
| `in_trash` | 1 = está na lixeira |
| `purged` | 1 = exclusão definitiva pendente de envio |
| `synced` | 1 = já igual ao Firestore |

**Firestore** — coleção `notes`, um documento por nota (ID = UUID), com os campos `userId`, `title`, `content`, `category`, `createdAt`, `updatedAt` e `inTrash`.

Todas as **consultas e pesquisas** são feitas no SQLite (`LIKE` em título e conteúdo), por isso funcionam mesmo sem internet. O Firestore serve como cópia na nuvem e fonte para recuperar dados em outra instalação.

## 8. Estratégia de sincronização e tratamento de erros

Abordagem **local-first**:

1. Toda alteração é gravada primeiro no SQLite com `synced = 0`.
2. O app tenta enviar ao Firestore. Se der certo, marca `synced = 1`.
3. Se falhar (sem internet, permissão negada), a nota continua pendente e o usuário vê um aviso.
4. Ao abrir a tela de notas, ou ao tocar no botão de sincronizar:
   - **envia** todas as notas pendentes;
   - **baixa** as notas do usuário que estão na nuvem.
5. **Conflitos:** vence a versão com `updatedAt` mais recente (last-write-wins). Uma nota local ainda pendente nunca é sobrescrita pela nuvem.
6. **Exclusão definitiva:** a nota recebe `purged = 1`, é apagada do Firestore e só então removida do SQLite. Se estiver offline, a exclusão fica pendente até a próxima sincronização.
7. **Exclusão em outro aparelho:** notas sincronizadas que não existem mais na nuvem são removidas do SQLite local.

**Erros tratados:** falha de rede ou de acesso ao Firebase (mensagem ao usuário e dados mantidos localmente) e erros de autenticação (e-mail inválido, senha fraca, e-mail já cadastrado, senha incorreta).

**Limitação conhecida:** o `LIKE` do SQLite ignora maiúsculas/minúsculas apenas para letras sem acento.

## 9. Autenticação e segurança dos dados

- Login e cadastro com e-mail e senha (Firebase Authentication).
- Cada nota guarda o `userId` do dono, e o app consulta com `where('userId', isEqualTo: uid)`.
- Regras do Firestore (`firestore.rules`):
  - ler, alterar e apagar: somente se `resource.data.userId == request.auth.uid`;
  - criar: somente se o `userId` enviado for o do usuário autenticado;
  - usuários não autenticados não têm acesso.
- Nenhuma senha, chave ou arquivo de credenciais é versionado.

## 10. Descrição do que foi desenvolvido

| Arquivo | O que faz |
|---|---|
| `main.dart` | Inicializa Firebase e o SQLite (inclusive para web) e escolhe a tela conforme o login |
| `models/note.dart` | Modelo da nota, com conversão para SQLite (`toMap`/`fromMap`) e Firestore (`toFirestore`/`fromFirestore`) |
| `data/local_db.dart` | Cria a tabela, grava, lista, filtra por categoria e pesquisa por título/conteúdo |
| `data/remote_repository.dart` | Grava, apaga e busca notas no Firestore |
| `data/note_repository.dart` | Salvar, lixeira, restaurar, excluir definitivamente e sincronizar |
| `services/auth_service.dart` | Entrar, criar conta, sair e observar o estado do login |
| `screens/login_screen.dart` | Tela de login com mensagens de erro |
| `screens/notes_screen.dart` | Lista, chips de categoria, pesquisa, lixeira, indicador de sincronização |
| `screens/note_edit_screen.dart` | Formulário de nota e criação de categoria |
| `firestore.rules` | Regras de segurança |

## 11. Capturas de tela

**Aplicativo**

| Login | Lista de notas | Nova nota |
|---|---|---|
| ![Login](docs/01-login.png) | ![Lista](docs/02-lista.png) | ![Edição](docs/03-edicao.png) |

| Pesquisa | Lixeira | Sem conexão |
|---|---|---|
| ![Pesquisa](docs/04-pesquisa.png) | ![Lixeira](docs/05-lixeira.png) | ![Offline](docs/06-offline.png) |

**Evidências no Firebase**

| Firestore (coleção `notes`) | Authentication (usuários) | Regras publicadas |
|---|---|---|
| ![Firestore](docs/07-firestore.png) | ![Auth](docs/08-auth.png) | ![Regras](docs/09-regras.png) |

## 12. Fluxo Git utilizado

1. Fork do repositório da professora.
2. Nova branch (`melhorias-bloco-notas`), sem desenvolver na `main`.
3. Commits com mensagens claras durante o desenvolvimento.
4. Pull Request do fork para a `main` do repositório original.
5. Link do fork enviado no Google Classroom.
