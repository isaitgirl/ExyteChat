# ExyteChat do isaCloud

Fork de `monal-im/ExyteChat` mantido para o app isaCloud para iOS (`isaitgirl/isaCloud-iOS`, fork do Monal). O app usa este pacote pelo branch `isaCloud`.

## Branches e PRs

- `main`: espelho do `main` de `monal-im/ExyteChat`. Não recebe mudanças do isaCloud.
- `isaCloud`: base das mudanças do isaCloud e o branch que o app usa.
- Toda mudança nasce em um branch novo criado **a partir de `isaCloud`** (por exemplo `feature/reaction-details-sheet`) e volta por **PR do branch novo para `isaCloud`**, dentro deste fork. Nunca abrir PR para `monal-im`, nem para `main`, sem decisão explícita.
- Todo PR tem a `isaitgirl` como revisora e responsável (`gh pr create --base isaCloud --reviewer isaitgirl --assignee isaitgirl`).
- Todo PR com mudança visível traz prints de antes e depois no app, feitos só com dados de teste. As capturas ficam em `docs/screenshots/` do repositório do app, no branch do PR correspondente.
- Mudanças que dependem do app têm um PR par no `isaitgirl/isaCloud-iOS`, que só entra depois deste.

O fluxo completo, incluindo como o app aponta para este pacote e como sincronizar com o Monal, está em `docs/exytechat-fork.md` no repositório do app.

## Convenções

- Mensagens de commit e PRs em português; código e nomes seguem o estilo do ExyteChat/Monal.
- Textos visíveis ao usuário entram em `Sources/ExyteChat/Model/ChatLocalization.swift` com `String(localized:)`, para o app preencher e traduzir.
- Manter as mudanças pequenas e isoladas, para facilitar merges futuros com o `monal-im/ExyteChat`.
- Dados sensíveis ou pessoais nunca entram em arquivos do repositório.
