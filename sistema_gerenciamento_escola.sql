-- Criação do banco de dados
CREATE DATABASE SistemaGerenciamentoEscola;
USE SistemaGerenciamentoEscola;

-- Tabela para armazenar informações de alunos
CREATE TABLE Alunos (
    aluno_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    data_nascimento DATE NOT NULL,
    email VARCHAR(100) UNIQUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para armazenar informações de professores
CREATE TABLE Professores (
    professor_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    especialidade VARCHAR(100),
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para armazenar informações de disciplinas
CREATE TABLE Disciplinas (
    disciplina_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    carga_horaria INT NOT NULL,
    professor_id INT,
    FOREIGN KEY (professor_id) REFERENCES Professores(professor_id) ON DELETE SET NULL
);

-- Tabela para armazenar notas dos alunos
CREATE TABLE Notas (
    nota_id INT AUTO_INCREMENT PRIMARY KEY,
    aluno_id INT NOT NULL,
    disciplina_id INT NOT NULL,
    nota DECIMAL(5, 2) NOT NULL CHECK (nota >= 0 AND nota <= 10),
    data_avaliacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (aluno_id) REFERENCES Alunos(aluno_id) ON DELETE CASCADE,
    FOREIGN KEY (disciplina_id) REFERENCES Disciplinas(disciplina_id) ON DELETE CASCADE
);

-- Tabela para armazenar presença dos alunos
CREATE TABLE Presencas (
    presenca_id INT AUTO_INCREMENT PRIMARY KEY,
    aluno_id INT NOT NULL,
    disciplina_id INT NOT NULL,
    data_presenca DATE NOT NULL,
    status ENUM('Presente', 'Faltou') NOT NULL,
    FOREIGN KEY (aluno_id) REFERENCES Alunos(aluno_id) ON DELETE CASCADE,
    FOREIGN KEY (disciplina_id) REFERENCES Disciplinas(disciplina_id) ON DELETE CASCADE,
    UNIQUE (aluno_id, disciplina_id, data_presenca)
);

-- Índices para melhorar a performance
CREATE INDEX idx_aluno_nome ON Alunos(nome);
CREATE INDEX idx_professor_nome ON Professores(nome);
CREATE INDEX idx_disciplina_nome ON Disciplinas(nome);
CREATE INDEX idx_nota_aluno ON Notas(aluno_id);
CREATE INDEX idx_presenca_aluno ON Presencas(aluno_id);

-- View para listar alunos com suas notas e presenças
CREATE VIEW ViewAlunosNotasPresencas AS
SELECT a.aluno_id, a.nome AS aluno, d.nome AS disciplina, n.nota, p.status, p.data_presenca
FROM Alunos a
LEFT JOIN Notas n ON a.aluno_id = n.aluno_id
LEFT JOIN Presencas p ON a.aluno_id = p.aluno_id
LEFT JOIN Disciplinas d ON n.disciplina_id = d.disciplina_id OR p.disciplina_id = d.disciplina_id
ORDER BY a.nome, d.nome;

-- Função para calcular a média de notas de um aluno em uma disciplina
DELIMITER //
CREATE FUNCTION MediaNotas(alunoId INT, disciplinaId INT) RETURNS DECIMAL(5, 2)
BEGIN
    DECLARE media DECIMAL(5, 2);
    SELECT AVG(nota) INTO media 
    FROM Notas 
    WHERE aluno_id = alunoId AND disciplina_id = disciplinaId;
    RETURN IFNULL(media, 0);
END //
DELIMITER ;

-- Trigger para garantir que um aluno não tenha notas duplicadas em uma disciplina
DELIMITER //
CREATE TRIGGER Trigger_AntesInserirNota
BEFORE INSERT ON Notas
FOR EACH ROW
BEGIN
    IF (SELECT COUNT(*) FROM Notas WHERE aluno_id = NEW.aluno_id AND disciplina_id = NEW.disciplina_id) > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nota já existe para este aluno na disciplina.';
    END IF;
END //
DELIMITER ;

-- Inserção de exemplo de alunos
INSERT INTO Alunos (nome, data_nascimento, email) VALUES 
('João Silva', '2000-05-15', 'joao.silva@example.com'),
('Maria Oliveira', '1998-08-22', 'maria.oliveira@example.com'),
('Pedro Santos', '1999-02-10', 'pedro.santos@example.com');

-- Inserção de exemplo de professores
INSERT INTO Professores (nome, email, especialidade) VALUES 
('Dr. Carlos Lima', 'carlos.lima@example.com', 'Matemática'),
('Prof. Ana Costa', 'ana.costa@example.com', 'História'),
('Profa. Rita Almeida', 'rita.almeida@example.com', 'Biologia');

-- Inserção de exemplo de disciplinas
INSERT INTO Disciplinas (nome, carga_horaria, professor_id) VALUES 
('Matemática', 60, 1),
('História', 40, 2),
('Biologia', 50, 3);

-- Inserção de exemplo de notas
INSERT INTO Notas (aluno_id, disciplina_id, nota) VALUES 
(1, 1, 8.5),
(1, 2, 9.0),
(2, 1, 7.5),
(2, 3, 8.0),
(3, 2, 6.5);

-- Inserção de exemplo de presenças
INSERT INTO Presencas (aluno_id, disciplina_id, data_presenca, status) VALUES 
(1, 1, '2024-10-01', 'Presente'),
(1, 2, '2024-10-02', 'Faltou'),
(2, 1, '2024-10-01', 'Presente'),
(3, 3, '2024-10-02', 'Presente');

-- Selecionar todos os alunos com suas notas e presenças
SELECT * FROM ViewAlunosNotasPresencas;

-- Obter a média de notas de um aluno em uma disciplina específica
SELECT MediaNotas(1, 1) AS media_aluno_1_disciplina_1;

-- Excluir uma nota
DELETE FROM Notas WHERE nota_id = 1;

-- Excluir um aluno (isso falhará se o aluno tiver notas ou presenças)
DELETE FROM Alunos WHERE aluno_id = 1;

-- Excluir uma disciplina (isso falhará se a disciplina tiver notas ou presenças)
DELETE FROM Disciplinas WHERE disciplina_id = 1;
