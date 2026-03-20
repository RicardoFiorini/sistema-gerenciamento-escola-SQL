# Sistema de Gerenciamento Escolar (SQL)
Uma infraestrutura de backend em SQL projetada para o **controle acadêmico** completo, desde o cadastro de usuários até a gestão de desempenho escolar.
## Funcionalidades do Sistema

- **Gestão de Pessoas:** Cadastro detalhado de alunos, professores e responsáveis.
- **Grade Curricular:** Organização de disciplinas por semestre ou ano letivo.
- **Matrículas e Turmas:** Controle de alocação de alunos em salas e horários específicos.
- **Avaliação:** Sistema de lançamento de notas e frequências.

## Status de Desenvolvimento
- [x] Modelagem do Diagrama de Entidades (DER)
- [x] Criação das tabelas e relacionamentos (FKs)
- [x] Scripts de consulta de boletins
- [ ] Implementar Procedures para cálculo automático de médias
## Exemplo de Consulta (Boletim do Aluno)
O script abaixo demonstra como recuperar as notas de um aluno específico em todas as disciplinas:
```sql

SELECT alunos.nome AS estudante, disciplinas.nome_materia, notas.valor
FROM notas
JOIN alunos ON notas.aluno_id = alunos.id
JOIN disciplinas ON notas.disciplina_id = disciplinas.id
WHERE alunos.matricula = '2023001';

```
## Dica de Organização
> [!TIP]
> Para facilitar a emissão de relatórios, utilize *Views* que consolidam as notas e faltas em uma única tabela virtual, otimizando o tempo de resposta do sistema.
## Arquitetura de Dados
| Tabela | Responsabilidade |
| --- | --- |
| alunos | Dados pessoais e número de matrícula |
| professores | Informações do corpo docente e especialidades |
| disciplinas | Ementas e carga horária das matérias |
| turmas | Vinculação entre alunos, professores e horários |
