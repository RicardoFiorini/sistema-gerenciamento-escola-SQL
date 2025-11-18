-- 1. Configuração
CREATE DATABASE IF NOT EXISTS SistemaGerenciamentoEscola
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;

USE SistemaGerenciamentoEscola;

-- 2. Entidades Base (Imutáveis)
CREATE TABLE PeriodosLetivos (
    periodo_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(20) NOT NULL UNIQUE, -- Ex: '2025-1', '2025-2'
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    ativo BOOLEAN DEFAULT FALSE -- Apenas um período ativo por vez
);

CREATE TABLE Disciplinas (
    disciplina_id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_mec VARCHAR(20) UNIQUE,
    nome VARCHAR(100) NOT NULL,
    ementa TEXT,
    carga_horaria INT NOT NULL
);

CREATE TABLE Pessoas (
    pessoa_id INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM('Aluno', 'Professor', 'Admin') NOT NULL,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    cpf VARCHAR(14) UNIQUE,
    data_nascimento DATE,
    ativo BOOLEAN DEFAULT TRUE,
    dados_extras JSON COMMENT 'Alergias, contatos de emergência, lattes',
    criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_busca_pessoa (nome, email, tipo)
);

-- 3. Estrutura de Classes (Onde o ensino acontece)
CREATE TABLE Turmas (
    turma_id INT AUTO_INCREMENT PRIMARY KEY,
    disciplina_id INT NOT NULL,
    professor_id INT NOT NULL,
    periodo_id INT NOT NULL,
    codigo_turma VARCHAR(20) NOT NULL, -- Ex: 'MAT-2025-A'
    sala VARCHAR(20),
    horario VARCHAR(50), -- Ex: 'Seg/Qua 08:00'
    encerrada BOOLEAN DEFAULT FALSE,
    
    FOREIGN KEY (disciplina_id) REFERENCES Disciplinas(disciplina_id),
    FOREIGN KEY (professor_id) REFERENCES Pessoas(pessoa_id),
    FOREIGN KEY (periodo_id) REFERENCES PeriodosLetivos(periodo_id),
    
    UNIQUE KEY uk_turma (disciplina_id, periodo_id, codigo_turma)
);

-- 4. Matrícula (O vínculo do aluno com a turma)
CREATE TABLE Matriculas (
    matricula_id INT AUTO_INCREMENT PRIMARY KEY,
    turma_id INT NOT NULL,
    aluno_id INT NOT NULL,
    media_final DECIMAL(5, 2) DEFAULT NULL,
    frequencia_percentual DECIMAL(5, 2) DEFAULT 100.00,
    status ENUM('Cursando', 'Aprovado', 'Reprovado', 'Recuperacao', 'Trancado') DEFAULT 'Cursando',
    
    FOREIGN KEY (turma_id) REFERENCES Turmas(turma_id),
    FOREIGN KEY (aluno_id) REFERENCES Pessoas(pessoa_id),
    UNIQUE KEY uk_matricula (turma_id, aluno_id) -- Aluno não pode estar 2x na mesma turma
);

-- 5. Definição de Avaliações (A regra do jogo)
CREATE TABLE AvaliacoesConfig (
    avaliacao_id INT AUTO_INCREMENT PRIMARY KEY,
    turma_id INT NOT NULL,
    nome VARCHAR(50) NOT NULL, -- P1, P2, Trabalho Final
    peso DECIMAL(5, 2) NOT NULL DEFAULT 1.0, -- Peso para média ponderada
    data_prevista DATE,
    
    FOREIGN KEY (turma_id) REFERENCES Turmas(turma_id) ON DELETE CASCADE
);

-- 6. Notas Lançadas (O resultado)
CREATE TABLE Notas (
    nota_id INT AUTO_INCREMENT PRIMARY KEY,
    matricula_id INT NOT NULL,
    avaliacao_id INT NOT NULL,
    valor DECIMAL(5, 2) NOT NULL CHECK (valor >= 0 AND valor <= 10),
    data_lancamento DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (matricula_id) REFERENCES Matriculas(matricula_id) ON DELETE CASCADE,
    FOREIGN KEY (avaliacao_id) REFERENCES AvaliacoesConfig(avaliacao_id) ON DELETE CASCADE,
    UNIQUE KEY uk_nota_unica (matricula_id, avaliacao_id)
);

-- 7. Controle de Frequência Diária
CREATE TABLE FrequenciaDiaria (
    frequencia_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    matricula_id INT NOT NULL,
    data_aula DATE NOT NULL,
    presente BOOLEAN NOT NULL DEFAULT FALSE,
    
    FOREIGN KEY (matricula_id) REFERENCES Matriculas(matricula_id) ON DELETE CASCADE,
    INDEX idx_freq_data (data_aula)
);

-- =========================================================
-- 🧠 INTELIGÊNCIA ACADÊMICA (PROCS & TRIGGERS)
-- =========================================================

-- VIEW: Boletim Escolar Detalhado
CREATE OR REPLACE VIEW v_BoletimEscolar AS
SELECT 
    pl.nome AS periodo,
    p.nome AS aluno,
    d.nome AS disciplina,
    t.codigo_turma,
    -- Subquery para concatenar notas (Ex: P1: 8.0 | P2: 7.0)
    (SELECT GROUP_CONCAT(CONCAT(ac.nome, ': ', n.valor) SEPARATOR ' | ')
     FROM Notas n 
     JOIN AvaliacoesConfig ac ON n.avaliacao_id = ac.avaliacao_id 
     WHERE n.matricula_id = m.matricula_id) AS notas_detalhadas,
    m.media_final,
    m.frequencia_percentual,
    m.status
FROM Matriculas m
JOIN Turmas t ON m.turma_id = t.turma_id
JOIN Disciplinas d ON t.disciplina_id = d.disciplina_id
JOIN PeriodosLetivos pl ON t.periodo_id = pl.periodo_id
JOIN Pessoas p ON m.aluno_id = p.pessoa_id;

-- PROCEDURE: Calcular Média e Atualizar Status (O Cérebro)
DELIMITER //
CREATE PROCEDURE sp_RecalcularMedia(IN p_matricula_id INT)
BEGIN
    DECLARE v_soma_notas DECIMAL(10,2);
    DECLARE v_soma_pesos DECIMAL(10,2);
    DECLARE v_media DECIMAL(5,2);
    
    -- 1. Cálculo de Média Ponderada
    SELECT 
        SUM(n.valor * ac.peso), 
        SUM(ac.peso)
    INTO v_soma_notas, v_soma_pesos
    FROM Notas n
    JOIN AvaliacoesConfig ac ON n.avaliacao_id = ac.avaliacao_id
    WHERE n.matricula_id = p_matricula_id;

    -- Evitar divisão por zero
    IF v_soma_pesos > 0 THEN
        SET v_media = v_soma_notas / v_soma_pesos;
    ELSE
        SET v_media = 0;
    END IF;

    -- 2. Atualizar Tabela Matrícula
    UPDATE Matriculas 
    SET media_final = v_media,
        status = CASE 
            WHEN v_media >= 7.0 THEN 'Aprovado'
            WHEN v_media < 4.0 THEN 'Reprovado'
            ELSE 'Recuperacao'
        END
    WHERE matricula_id = p_matricula_id;
    
END //
DELIMITER ;

-- TRIGGER: Dispara o Recálculo sempre que uma nota muda
DELIMITER //
CREATE TRIGGER trg_AposInserirNota
AFTER INSERT ON Notas
FOR EACH ROW
BEGIN
    CALL sp_RecalcularMedia(NEW.matricula_id);
END //

CREATE TRIGGER trg_AposAtualizarNota
AFTER UPDATE ON Notas
FOR EACH ROW
BEGIN
    CALL sp_RecalcularMedia(NEW.matricula_id);
END //

-- Trigger para Controle de Frequência (Atualiza % na Matrícula)
CREATE TRIGGER trg_AtualizarFrequencia
AFTER INSERT ON FrequenciaDiaria
FOR EACH ROW
BEGIN
    DECLARE v_total_aulas INT;
    DECLARE v_presencas INT;
    
    -- Conta total de registros para essa matrícula
    SELECT COUNT(*), SUM(CASE WHEN presente = 1 THEN 1 ELSE 0 END)
    INTO v_total_aulas, v_presencas
    FROM FrequenciaDiaria
    WHERE matricula_id = NEW.matricula_id;
    
    UPDATE Matriculas 
    SET frequencia_percentual = (v_presencas / v_total_aulas) * 100
    WHERE matricula_id = NEW.matricula_id;
END //
DELIMITER ;
