# Lex Temporis

Arquitetura de banco de dados temporal imutável baseada no padrão **Slowly Changing Dimensions (SCD) Tipo 2** em **PostgreSQL 16**, projetada para versionamento legislativo e recuperação histórica exata de normas jurídicas (*time-travel queries*).

Trabalho de Conclusão de Curso (TCC) desenvolvido no curso de **Ciência da Computação** da **Universidade Tiradentes (UNIT)**.

## Motivação

Sistemas jurídicos convencionais e modelos de Inteligência Artificial frequentemente falham ao responder consultas históricas porque bancos de dados tradicionais sobrescrevem o texto da lei por meio de operações destrutivas (`UPDATE`). No Direito Penal, a regra *tempus regit actum* exige que um fato seja julgado conforme a redação vigente na data de sua ocorrência (salvo retroatividade benéfica, Art. 5º, XL, da Constituição Federal).

O **Lex Temporis** resolve esse problema no nível do SGBD, garantindo integridade temporal, rastreabilidade e imutabilidade lógica dos registros legislativos.

## Arquitetura e Recursos

- **Versionamento SCD Tipo 2:** Controle explícito de vigência por intervalos fechados inclusivos (`'[]'`) via `data_inicio_vigencia` e `data_fim_vigencia` (encerramento na véspera, `D - 1`).
- **Prevenção Matemática de Sobreposições:** Restrição `EXCLUDE USING gist` (`sem_sobreposicao`) com `daterange` e extensão `btree_gist`, impedindo que um mesmo dispositivo possua duas redações vigentes simultaneamente (ou duas versões abertas com `NULL`).
- **Imutabilidade Lógica:** Gatilhos (`triggers`) que bloqueiam exclusões físicas (`DELETE` e `TRUNCATE`), adulterações em campos históricos via `UPDATE` e a alteração ou reabertura de vigências já encerradas.
- **API Temporal em PL/pgSQL:** Função `fn_texto_na_data(dispositivo_id, data)` utilizando o operador de pertinência `@>` diretamente sobre o índice GiST para recuperação pontual da redação vigente em qualquer data.
- **Performance sob Carga:** Reaproveitamento direto do índice GiST da restrição `sem_sobreposicao` (sem índice B-Tree redundante), validado em **1.000 consultas temporais aleatórias** sobre **1 milhão de versões contíguas** do dispositivo `999`:
  - **Com índice GiST (`Index Scan`):** `p50 = 0,044 ms` | `p95 = 0,077 ms` | `p99 = 0,117 ms` (inspeção individual: `0,073 ms`, 4 *buffers*).
  - **Sem índice (`Parallel Seq Scan`):** `68,164 ms` (11.427 *buffers*).

## Estrutura do Repositório

| Arquivo | Descrição |
| :--- | :--- |
| `01_ddl_tabelas.sql` | Criação da extensão `btree_gist`, tabelas (`documento_legal`, `dispositivo`, `versao_texto`) e restrição `EXCLUDE USING gist` (`sem_sobreposicao`). |
| `02_triggers_seguranca.sql` | Funções e gatilhos de auditoria que impedem `DELETE`, `TRUNCATE`, `UPDATE` em campos históricos e reabertura de vigências encerradas. |
| `03_funcao_temporal.sql` | Função `fn_texto_na_data` (RF3) para consultas de viagem no tempo e extensões estruturais opcionais (RF4 e RF5). |
| `04_carga_art154a.sql` | Prova de conceito com a evolução real do *caput* do **Art. 154-A do Código Penal** (Lei nº 12.737/2012 e Lei nº 14.155/2021) e testes `C1–C4` e `R1–R4`. |
| `05_stress_test.sql` | Script de benchmark que injeta 1.000.000 de versões contíguas no dispositivo `999`, executa `VACUUM ANALYZE`, mede `p50`/`p95`/`p99` em 1.000 consultas aleatórias e compara contra `Parallel Seq Scan`. |

## Como Reproduzir o Experimento

### Pré-requisitos
- [Docker](https://www.docker.com/) instalado e em execução.
- Cliente SQL de sua preferência (ex.: [DBeaver](https://dbeaver.io/) ou `psql`).

### 1. Subir o contêiner PostgreSQL 16
```bash
docker run --name lex-temporis -e POSTGRES_PASSWORD=senha123 -p 5432:5432 -d postgres:16
```

### 2. Executar os scripts na ordem
Conecte-se ao banco (`localhost:5432`, usuário `postgres`, senha `senha123`) e execute os arquivos exatamente nesta sequência:

1. `01_ddl_tabelas.sql`
2. `02_triggers_seguranca.sql`
3. `03_funcao_temporal.sql`
4. `04_carga_art154a.sql`
5. `05_stress_test.sql` *(leva cerca de 1 a 2 minutos)*

### 3. Validar as consultas temporais
```sql
SELECT fn_texto_na_data(154, '2015-05-10') AS teste_2015,
       fn_texto_na_data(154, '2013-04-01') AS teste_vespera,
       fn_texto_na_data(154, CURRENT_DATE) AS teste_atual,
       (SELECT COUNT(*) FROM versao_texto) AS total_versoes;
```

**Resultado esperado:**
- **`teste_2015`:** `Pena - detenção, de 3 (três) meses a 1 (um) ano, e multa.`
- **`teste_vespera`:** `NULL` *(data anterior à vigência original)*
- **`teste_atual`:** `Pena - reclusão, de 1 (um) a 4 (quatro) anos, e multa.`
- **`total_versoes`:** `1000002`

## Autor

**Christiano Brito Mota**  
Bacharelando em Ciência da Computação — Universidade Tiradentes (UNIT)  
Orientação: Prof. Me. Sérgio Roberto Santos de Santana
