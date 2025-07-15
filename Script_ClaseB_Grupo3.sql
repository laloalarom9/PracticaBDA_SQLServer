-- ========================================
-- PASO 1.1: CREACION DE LA BASE DE DATOS
-- ========================================
-- Creamos la base de datos 'PracticaBDA' en la ruta personalizada C:\Datos
-- Se definen dos archivos: uno de datos y uno de log.
-- Se establece una dimension inicial y el crecimiento automatico.

CREATE DATABASE PracticaBDA
ON PRIMARY (
    NAME = PracticaBDA_data,
    FILENAME = 'C:\Datos\PracticaBDA_data.mdf',
    SIZE = 10MB,
    FILEGROWTH = 50MB
)
LOG ON (
    NAME = PracticaBDA_log,
    FILENAME = 'C:\Datos\PracticaBDA_log.ldf',
    SIZE = 5MB,
    FILEGROWTH = 20MB
);
GO

PRINT 'Base de datos PracticaBDA creada con exito.';
-- ========================================
-- PASO 1.2: CREACION DE LA CLAVE MAESTRA (EN MASTER)
-- ========================================
-- Esta clave es necesaria para cifrar otros elementos como certificados.
-- Solo se necesita hacer una vez por instancia (si ya existe, se omite).

USE master;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Libert@d25';
GO

PRINT 'Clave maestra creada correctamente en master.';
-- ========================================
-- PASO 1.3: CREACION DEL CERTIFICADO PARA TDE
-- ========================================
-- Este certificado protegera la clave de cifrado de la base de datos.

CREATE CERTIFICATE CertificadoTDE
WITH SUBJECT = 'Certificado para cifrado de la base de datos PracticaBDA';
GO

PRINT 'Certificado CertificadoTDE creado correctamente.';
-- ========================================
-- PASO 1.4: CREACION DE LA CLAVE DE CIFRADO (DEK)
-- ========================================
-- Esta clave se crea en la base de datos y se cifra con el certificado creado.

USE PracticaBDA;
GO

CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE CertificadoTDE;
GO

PRINT 'Database Encryption Key creada en PracticaBDA.';
-- ========================================
-- PASO 1.4.1: Backup del certificado de cifrado
-- ========================================
-- Este paso es importante porque si pierdo este certificado,
-- no voy a poder restaurar la base de datos en otro equipo.
-- Asi que aqui hago una copia del certificado que se use para cifrar.

USE master;
GO

-- Creo el backup del certificado 'CertificadoTDE' y su clave privada.
-- Es necesario proteger esta clave privada con una clave.
-- En este caso, uso la misma que use para la clave maestra ('Libert@d25').

BACKUP CERTIFICATE CertificadoTDE
TO FILE = 'C:\Backup\CertificadoTDE.cer' -- Aqui se guarda el certificado
WITH PRIVATE KEY (
    FILE = 'C:\Backup\CertificadoTDE.key', -- Aqui se guarda la clave privada
    ENCRYPTION BY PASSWORD = 'Libert@d25'  -- Clave para proteger el backup
);
GO

-- Si todo sale bien, este mensaje me confirma que el backup se ha hecho.
PRINT ' Certificado y clave privada respaldados correctamente.';


-- ========================================
-- PASO 1.5: ACTIVACION DEL CIFRADO EN LA BASE DE DATOS
-- ========================================
-- A partir de este momento, la base queda cifrada a nivel de archivo.

ALTER DATABASE PracticaBDA
SET ENCRYPTION ON;
GO

PRINT 'Cifrado TDE activado correctamente en PracticaBDA.';
-- ========================================
-- PASO 1.6: VERIFICACION DEL ESTADO DE CIFRADO
-- ========================================
-- Se consulta la vista del sistema que muestra si el cifrado esta activo.

SELECT 
    db.name AS NombreBD,
    dek.encryption_state AS Estado,
    CASE dek.encryption_state
        WHEN 0 THEN 'Sin clave de cifrado'
        WHEN 1 THEN 'Clave creada, cifrado no activado'
        WHEN 2 THEN 'Cifrado en progreso'
        WHEN 3 THEN 'Cifrado activo'
        ELSE 'Otro estado'
    END AS EstadoDescripcion
FROM sys.dm_database_encryption_keys dek
JOIN sys.databases db ON dek.database_id = db.database_id
WHERE db.name = 'PracticaBDA';
GO
-- ========================================
-- PASO 2.1: CREACION DE ESQUEMAS
-- ========================================
-- Creamos varios esquemas para organizar las tablas por area logica.
-- Esto mejora la claridad, el mantenimiento y la gestion de permisos.

USE PracticaBDA;
GO

CREATE SCHEMA Alumnos;
GO

CREATE SCHEMA Asignaturas;
GO

CREATE SCHEMA Grupos;
GO

CREATE SCHEMA Evaluacion;
GO

PRINT 'Esquemas creados correctamente: Alumnos, Asignaturas, Grupos, Evaluacion.';

-- Verificacion de los esquemas que hemos creado en la base de datos PracticaBDA.
-- Esto nos permite confirmar que estan los nombres correctos y que no ha habido errores de escritura.

SELECT name AS NombreEsquema
FROM sys.schemas
WHERE name IN ('Alumnos', 'Asignaturas', 'Grupos', 'Evaluacion');

-- ========================================
-- PASO 2.2: CREACION DE GRUPOS DE ARCHIVOS Y ARCHIVOS
-- ========================================
-- Creamos nuevos FILEGROUPs para simular un entorno eficiente de almacenamiento.
-- Cada uno puede estar asociado a una particion (por ejemplo, por curso).
-- Aqui solo simulamos todos apuntando a la misma ruta por simplicidad.

ALTER DATABASE PracticaBDA ADD FILEGROUP FG_1A;
ALTER DATABASE PracticaBDA ADD FILEGROUP FG_2A;
ALTER DATABASE PracticaBDA ADD FILEGROUP FG_3A;
GO

ALTER DATABASE PracticaBDA 
ADD FILE (
    NAME = PracticaBDA_FG1A,
    FILENAME = 'C:\Datos\PracticaBDA_FG1A.ndf',
    SIZE = 5MB,
    FILEGROWTH = 20MB
) TO FILEGROUP FG_1A;

ALTER DATABASE PracticaBDA 
ADD FILE (
    NAME = PracticaBDA_FG2A,
    FILENAME = 'C:\Datos\PracticaBDA_FG2A.ndf',
    SIZE = 5MB,
    FILEGROWTH = 20MB
) TO FILEGROUP FG_2A;

ALTER DATABASE PracticaBDA 
ADD FILE (
    NAME = PracticaBDA_FG3A,
    FILENAME = 'C:\Datos\PracticaBDA_FG3A.ndf',
    SIZE = 5MB,
    FILEGROWTH = 20MB
) TO FILEGROUP FG_3A;

PRINT 'Grupos de archivos y archivos .ndf creados correctamente.';

-- Verifica todos los archivos de la base de datos y a que FILEGROUP estan asociados
USE PracticaBDA;
GO

SELECT 
    name AS NombreArchivo,
    physical_name AS RutaFisica,
    type_desc AS Tipo,
    FILEGROUP_NAME(data_space_id) AS Filegroup
FROM sys.database_files;

-- ========================================
-- PASO 2.3: FUNCION DE PARTICION
-- ========================================
-- Esta funcion dividira la tabla Tb_Grupos por el campo Curso.

CREATE PARTITION FUNCTION PF_CursoGrupo (INT)
AS RANGE LEFT FOR VALUES (1, 2); -- Cursos 1A, 2A, 3A -> genera 3 particiones
GO

PRINT 'Funcion de particion PF_CursoGrupo creada.';
-- ============================================
-- VERIFICACION DE LA FUNCION DE PARTICION
-- ============================================
-- Esta consulta nos ayuda a comprobar si la funcion PF_CursoGrupo fue creada bien.
-- Nos muestra los valores que se usaron como "limites" para dividir los datos.
-- En nuestro caso, queremos dividir por el campo Curso en los valores 1 y 2.
-- Aunque solo aparecen dos filas, eso significa que SQL Server creo TRES particiones:
--   - Una para Curso <= 1
--   - Otra para Curso = 2
--   - Y una tercera para Curso > 2

SELECT 
    pf.name AS NombreFuncion,                 -- Nombre de la funcion
    pf.function_id,                           -- ID interno (informativo)
    pf.boundary_value_on_right AS LimiteDerecho, -- Si vale 0 es RANGE LEFT (como usamos nosotros)
    prv.value AS ValoresLimite                -- Los cortes que marcan las particiones
FROM sys.partition_functions pf
JOIN sys.partition_range_values prv 
    ON pf.function_id = prv.function_id;

-- ========================================
-- PASO 2.4: ESQUEMA DE PARTICION
-- ========================================
-- Asocia cada rango definido por la funcion a un FILEGROUP.
-- El orden debe coincidir con el numero de particiones (n+1).

CREATE PARTITION SCHEME PS_CursoGrupo
AS PARTITION PF_CursoGrupo
TO (FG_1A, FG_2A, FG_3A); -- curso 1A, 2A, 3A
GO

PRINT 'Esquema de particion PS_CursoGrupo creado correctamente.';
-- ============================================
-- VERIFICACION DEL ESQUEMA DE PARTICION
-- ============================================
-- Esta consulta nos muestra como se distribuyen las particiones que creamos.
-- Lo que hace es indicar a que FILEGROUP (archivo .ndf) va cada una de las particiones.
-- Asi nos aseguramos de que los cursos 1, 2 y 3 se estan guardando en archivos diferentes.

SELECT 
    ps.name AS EsquemaParticion,        -- Nombre del esquema (deberia ser PS_CursoGrupo)
    ds.destination_id AS Particion,     -- Numero de la particion (1, 2, 3)
    fg.name AS Filegroup                -- Nombre del grupo de archivos al que apunta esa particion
FROM sys.partition_schemes ps
JOIN sys.destination_data_spaces ds 
    ON ps.data_space_id = ds.partition_scheme_id
JOIN sys.filegroups fg 
    ON ds.data_space_id = fg.data_space_id
WHERE ps.name = 'PS_CursoGrupo';



-- ========================================
-- CREAR TABLAS
-- ========================================
-- ========================================
-- Tabla: Alumnos.Tb_Alumnos
-- ========================================
CREATE TABLE Alumnos.Tb_Alumnos (
    IdAlumno INT PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Curso INT NOT NULL CHECK (Curso BETWEEN 1 AND 3),
    Clase CHAR(1) NOT NULL CHECK (Clase IN ('A', 'B', 'C'))
);
GO

PRINT 'Tabla Tb_Alumnos creada correctamente.';
-- ========================================
-- Tabla: Asignaturas.Tb_Asignaturas
-- ========================================
CREATE TABLE Asignaturas.Tb_Asignaturas (
    IdAsignatura INT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Curso INT NOT NULL CHECK (Curso BETWEEN 1 AND 3),
    Profesor VARCHAR(100) NOT NULL
);
GO

PRINT 'Tabla Tb_Asignaturas creada correctamente.';
-- ========================================
-- Tabla: Grupos.Tb_Grupos (PARTICIONADA POR Curso)
-- ========================================
-- Se usa el esquema de particion PS_CursoGrupo definido previamente.

CREATE TABLE Grupos.Tb_Grupos (
    IdGrupo INT NOT NULL,
    IdAsignatura INT NOT NULL,
    Curso INT NOT NULL CHECK (Curso BETWEEN 1 AND 3),
    PRIMARY KEY (Curso, IdGrupo),
    FOREIGN KEY (IdAsignatura) REFERENCES Asignaturas.Tb_Asignaturas(IdAsignatura)
)
ON PS_CursoGrupo(Curso); -- <- Aqui se aplica la particion
GO

PRINT 'Tabla Tb_Grupos creada y particionada por Curso correctamente.';
-- ========================================
-- Tabla: Grupos.Tb_Alum_Grupo
-- ========================================
-- Relaciona alumnos con grupos. Un alumno solo puede estar en un grupo por asignatura.

CREATE TABLE Grupos.Tb_Alum_Grupo (
    IdAlumno INT NOT NULL,
    IdGrupo INT NOT NULL,
    Curso INT NOT NULL,
    PRIMARY KEY (IdAlumno, IdGrupo),
    FOREIGN KEY (IdAlumno) REFERENCES Alumnos.Tb_Alumnos(IdAlumno),
    FOREIGN KEY (Curso, IdGrupo) REFERENCES Grupos.Tb_Grupos(Curso, IdGrupo)
);
GO

PRINT 'Tabla Tb_Alum_Grupo creada correctamente.';
-- ========================================
-- Tabla: Evaluacion.Tb_Calificaciones
-- ========================================
-- Guarda las notas por rubrica de cada alumno en una asignatura

CREATE TABLE Evaluacion.Tb_Calificaciones (
    IdAlumno INT NOT NULL,
    IdAsignatura INT NOT NULL,
    Criterio VARCHAR(50) NOT NULL,
    Nota DECIMAL(4,2) NOT NULL CHECK (Nota BETWEEN 0 AND 10),
    PRIMARY KEY (IdAlumno, IdAsignatura, Criterio),
    FOREIGN KEY (IdAlumno) REFERENCES Alumnos.Tb_Alumnos(IdAlumno),
    FOREIGN KEY (IdAsignatura) REFERENCES Asignaturas.Tb_Asignaturas(IdAsignatura)
);
GO

PRINT 'Tabla Tb_Calificaciones creada correctamente.';
-- ========================================
-- Tabla: Grupos.Tb_Alum_NoGrupo
-- ========================================
-- Guarda alumnos que han sido expulsados de algun grupo.

CREATE TABLE Grupos.Tb_Alum_NoGrupo (
    IdAlumno INT NOT NULL,
    IdAsignatura INT NOT NULL,
    FechaSalida DATETIME DEFAULT GETDATE(),
    PRIMARY KEY (IdAlumno, IdAsignatura),
    FOREIGN KEY (IdAlumno) REFERENCES Alumnos.Tb_Alumnos(IdAlumno),
    FOREIGN KEY (IdAsignatura) REFERENCES Asignaturas.Tb_Asignaturas(IdAsignatura)
);
GO

PRINT 'Tabla Tb_Alum_NoGrupo creada correctamente.';
-- ========================================
-- Verificacion rapida de todas las tablas por esquema
-- ========================================
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name;
-- ========================================
-- INSERTS: Alumnos.Tb_Alumnos
-- ========================================
INSERT INTO Alumnos.Tb_Alumnos (IdAlumno, Nombre, Apellidos, Curso, Clase) VALUES
(1, 'Maria', 'Lopez Sanchez', 1, 'A'),
(2, 'Javier', 'Ramirez Gomez', 2, 'A'),
(3, 'Lucia', 'Martin Cano', 3, 'A'),
(4, 'Andres', 'Perez Diaz', 1, 'A'),
(5, 'Elena', 'Ruiz Fernandez', 2, 'A');
GO
-- ========================================
-- INSERTS: Asignaturas.Tb_Asignaturas
-- ========================================
INSERT INTO Asignaturas.Tb_Asignaturas (IdAsignatura, Nombre, Curso, Profesor) VALUES
(101, 'Bases de Datos Avanzadas', 1, 'Antonio Garcia'),
(102, 'Programacion', 2, 'Laura Hernandez'),
(103, 'Redes', 3, 'Alberto Torres');
GO
-- ========================================
-- INSERTS: Grupos.Tb_Grupos
-- ========================================
INSERT INTO Grupos.Tb_Grupos (IdGrupo, IdAsignatura, Curso) VALUES
(1, 101, 1),  -- Curso 1A
(2, 101, 1),
(3, 102, 2),  -- Curso 2A
(4, 102, 2),
(5, 103, 3);  -- Curso 3A
GO
-- ========================================
-- INSERTS: Grupos.Tb_Alum_Grupo
-- ========================================
INSERT INTO Grupos.Tb_Alum_Grupo (IdAlumno, IdGrupo, Curso) VALUES
(1, 1, 1),
(4, 2, 1),
(2, 3, 2),
(5, 3, 2);
GO
-- ========================================
-- INSERTS: Evaluacion.Tb_Calificaciones
-- ========================================
INSERT INTO Evaluacion.Tb_Calificaciones (IdAlumno, IdAsignatura, Criterio, Nota) VALUES
(1, 101, 'Estructura SQL', 8.5),
(1, 101, 'Seguridad', 9.0),
(2, 102, 'Logica de Programacion', 7.5),
(5, 102, 'Eficiencia', 8.0);
GO
-- ========================================
-- INSERTS: Grupos.Tb_Alum_NoGrupo
-- ========================================
INSERT INTO Grupos.Tb_Alum_NoGrupo (IdAlumno, IdAsignatura) VALUES
(3, 103); -- Lucia queda sin grupo
GO
-- ========================================
-- Verificacion rapida de contenido
-- ========================================
SELECT * FROM Alumnos.Tb_Alumnos;
SELECT * FROM Asignaturas.Tb_Asignaturas;
SELECT * FROM Grupos.Tb_Grupos;
SELECT * FROM Grupos.Tb_Alum_Grupo;
SELECT * FROM Evaluacion.Tb_Calificaciones;
SELECT * FROM Grupos.Tb_Alum_NoGrupo;
-- ========================================
-- Vista: vw_Grupos_Profesor
-- ========================================
-- Muestra los grupos, alumnos y curso de las asignaturas impartidas por un profesor.

CREATE VIEW Grupos.vw_Grupos_Profesor
AS
SELECT 
    ASIG.Profesor,
    G.IdGrupo,
    G.Curso,
    ASIG.Nombre AS NombreAsignatura,
    AL.IdAlumno,
    AL.Nombre AS NombreAlumno,
    AL.Apellidos,
    AL.Clase
FROM Grupos.Tb_Grupos G
JOIN Asignaturas.Tb_Asignaturas ASIG ON G.IdAsignatura = ASIG.IdAsignatura
JOIN Grupos.Tb_Alum_Grupo AG ON G.IdGrupo = AG.IdGrupo AND G.Curso = AG.Curso
JOIN Alumnos.Tb_Alumnos AL ON AL.IdAlumno = AG.IdAlumno;
GO

PRINT 'Vista vw_Grupos_Profesor creada correctamente.';
-- ========================================
-- Vista: vw_Grupos_PEC
-- ========================================
-- Muestra todos los grupos y alumnos por curso (vista global por curso).

CREATE VIEW Grupos.vw_Grupos_PEC
AS
SELECT 
    G.Curso,
    G.IdGrupo,
    ASIG.Nombre AS NombreAsignatura,
    AL.IdAlumno,
    AL.Nombre AS NombreAlumno,
    AL.Apellidos,
    AL.Clase
FROM Grupos.Tb_Grupos G
JOIN Asignaturas.Tb_Asignaturas ASIG ON G.IdAsignatura = ASIG.IdAsignatura
LEFT JOIN Grupos.Tb_Alum_Grupo AG ON G.IdGrupo = AG.IdGrupo AND G.Curso = AG.Curso
LEFT JOIN Alumnos.Tb_Alumnos AL ON AG.IdAlumno = AL.IdAlumno;
GO

PRINT 'Vista vw_Grupos_PEC creada correctamente.';
-- ========================================
-- Ver grupos de un profesor especifico
-- ========================================
SELECT * FROM Grupos.vw_Grupos_Profesor WHERE Profesor = 'Antonio Garcia'ORDER BY IdGrupo;
-- ========================================
-- Ver todos los grupos del curso 2
SELECT * FROM Grupos.vw_Grupos_PEC WHERE Curso = 2 ORDER BY IdGrupo;

-- ========================================

-- ========================================
-- sp_AsignaturasPorCurso PROCEDIMIENTO
-- ========================================
-- Permite a un alumno ver que asignaturas se imparten en un curso.

CREATE PROCEDURE dbo.sp_AsignaturasPorCurso
    @Curso INT
AS
BEGIN
    SELECT IdAsignatura, Nombre, Profesor
    FROM Asignaturas.Tb_Asignaturas
    WHERE Curso = @Curso;
END;
GO

PRINT 'Procedimiento sp_AsignaturasPorCurso creado correctamente.';
-- ========================================
-- Verificacion
-- ========================================
EXEC dbo.sp_AsignaturasPorCurso @Curso = 1;
-- ========================================
-- sp_GruposPorAsignatura PROCEDIMIENTO
-- ========================================
-- Muestra todos los grupos disponibles para una asignatura.

CREATE PROCEDURE dbo.sp_GruposPorAsignatura
    @IdAsignatura INT
AS
BEGIN
    SELECT IdGrupo, Curso
    FROM Grupos.Tb_Grupos
    WHERE IdAsignatura = @IdAsignatura;
END;
GO

PRINT 'Procedimiento sp_GruposPorAsignatura creado correctamente.';
-- ========================================
-- Verificacion
-- ========================================
EXEC dbo.sp_GruposPorAsignatura @IdAsignatura = 101;
-- ========================================
-- sp_UnirseAGrupo PROCEDIMIENTO
-- ========================================
-- Permite a un alumno unirse a un grupo si existe y tiene menos de 5 miembros.

CREATE PROCEDURE dbo.sp_UnirseAGrupo
    @IdAlumno INT,
    @IdGrupo INT,
    @Curso INT
AS
BEGIN
    -- Verificar existencia del grupo
    IF NOT EXISTS (
        SELECT 1 FROM Grupos.Tb_Grupos
        WHERE IdGrupo = @IdGrupo AND Curso = @Curso
    )
    BEGIN
        PRINT 'El grupo indicado no existe.';
        RETURN;
    END

    -- Verificar si ya hay 5 alumnos
    IF (
        SELECT COUNT(*) FROM Grupos.Tb_Alum_Grupo
        WHERE IdGrupo = @IdGrupo AND Curso = @Curso
    ) >= 5
    BEGIN
        PRINT 'El grupo ya esta completo.';
        RETURN;
    END

    -- Insertar si pasa ambas validaciones
    INSERT INTO Grupos.Tb_Alum_Grupo (IdAlumno, IdGrupo, Curso)
    VALUES (@IdAlumno, @IdGrupo, @Curso);

    PRINT 'Alumno asignado correctamente al grupo.';
END;
GO

PRINT 'Procedimiento sp_UnirseAGrupo creado correctamente.';

-- ========================================
-- PRUEBAS: sp_UnirseAGrupo
-- ========================================

-- ----------------------------------------
-- PRUEBA 1 – Fallida (grupo no existe para ese curso)
-- ----------------------------------------

-- Se intenta insertar al alumno 4 en el grupo 3 del curso 1,
-- pero ese grupo pertenece al curso 2, asi que no se insertara.

EXEC dbo.sp_UnirseAGrupo @IdAlumno = 4, @IdGrupo = 3, @Curso = 1;

-- Confirmamos que el grupo 3 NO pertenece al curso 1
SELECT * 
FROM Grupos.Tb_Grupos 
WHERE IdGrupo = 3 AND Curso = 1;

-- ----------------------------------------
-- PRUEBA 2 – Funcional (grupo valido y con espacio)
-- ----------------------------------------

-- Se asigna al alumno 4 al grupo 1 del curso 1, que si existe
EXEC dbo.sp_UnirseAGrupo @IdAlumno = 4, @IdGrupo = 1, @Curso = 1;

-- Verificamos si el alumno fue insertado correctamente
SELECT * 
FROM Grupos.Tb_Alum_Grupo 
WHERE IdAlumno = 4 AND IdGrupo = 1 AND Curso = 1;

-- ========================================
-- sp_CrearGrupo PROCEDIMIENTO
-- ========================================
-- Permite a un profesor crear un grupo si no existe ya para su asignatura y curso.

CREATE PROCEDURE dbo.sp_CrearGrupo
    @IdGrupo INT,
    @IdAsignatura INT,
    @Curso INT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM Grupos.Tb_Grupos
        WHERE IdGrupo = @IdGrupo AND Curso = @Curso
    )
    BEGIN
        PRINT 'Ya existe un grupo con ese ID en ese curso.';
        RETURN;
    END

    INSERT INTO Grupos.Tb_Grupos (IdGrupo, IdAsignatura, Curso)
    VALUES (@IdGrupo, @IdAsignatura, @Curso);

    PRINT 'Grupo creado correctamente.';
END;
GO

PRINT 'Procedimiento sp_CrearGrupo creado correctamente.';
-- ========================================
-- Verificacion
-- ========================================
EXEC dbo.sp_CrearGrupo @IdGrupo = 6, @IdAsignatura = 101, @Curso = 1;
SELECT * FROM Grupos.Tb_Grupos WHERE IdGrupo = 6 AND Curso = 1;
-- ========================================
-- sp_CrearGruposAutomaticos PROCEDIMIENTO
-- ========================================
-- Crea automaticamente grupos para una asignatura de un curso segun el total de alumnos.

CREATE PROCEDURE dbo.sp_CrearGruposAutomaticos
    @IdAsignatura INT,
    @Curso INT
AS
BEGIN
    DECLARE @TotalAlumnos INT;
    SELECT @TotalAlumnos = COUNT(*) FROM Alumnos.Tb_Alumnos WHERE Curso = @Curso;

    DECLARE @NumGrupos INT = (@TotalAlumnos / 5) + 1;
    DECLARE @i INT = 1;

    WHILE @i <= @NumGrupos
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM Grupos.Tb_Grupos
            WHERE IdGrupo = @i AND Curso = @Curso
        )
        BEGIN
            INSERT INTO Grupos.Tb_Grupos (IdGrupo, IdAsignatura, Curso)
            VALUES (@i, @IdAsignatura, @Curso);
        END
        SET @i += 1;
    END

    PRINT 'Grupos generados automaticamente.';
END;
GO

PRINT 'Procedimiento sp_CrearGruposAutomaticos creado correctamente.';

-- ========================================
-- Verificacion
-- ========================================
EXEC dbo.sp_CrearGruposAutomaticos @IdAsignatura = 102, @Curso = 2;
SELECT * FROM Grupos.Tb_Grupos WHERE Curso = 2 AND IdAsignatura = 102 ORDER BY IdGrupo;

-- ========================================
-- Creacion de los usuarios
-- ========================================
--Logins
USE master;
GO

CREATE LOGIN alumno WITH PASSWORD = 'Libert@d25';
CREATE LOGIN profesor WITH PASSWORD = 'Libert@d25';
CREATE LOGIN pec WITH PASSWORD = 'Libert@d25';
GO
--Usuarios dentro de la Base de Datos
USE PracticaBDA;
GO

CREATE USER alumno FOR LOGIN alumno;
CREATE USER profesor FOR LOGIN profesor;
CREATE USER pec FOR LOGIN pec;
GO

-- ========================================
-- Asignamos permisos a roles de usuarios
-- ========================================
GRANT EXEC ON dbo.sp_AsignaturasPorCurso TO alumno;
GRANT EXEC ON dbo.sp_GruposPorAsignatura TO alumno;
GRANT EXEC ON dbo.sp_UnirseAGrupo TO alumno;

GRANT EXEC ON dbo.sp_CrearGrupo TO profesor;

GRANT EXEC ON dbo.sp_CrearGruposAutomaticos TO pec;
-- ========================================
-- Ejemplos de prueba
-- ========================================
EXEC dbo.sp_AsignaturasPorCurso @Curso = 2;
EXEC dbo.sp_GruposPorAsignatura @IdAsignatura = 101;
EXEC dbo.sp_UnirseAGrupo @IdAlumno = 4, @IdGrupo = 3, @Curso = 1;

-- ========================================
-- PRUEBAS DE ACCESO POR USUARIO
-- ========================================

-- ========================================
-- Usuario: alumno
-- ========================================

-- Prueba permitida (ver asignaturas por curso)
-- Esperado: muestra las asignaturas del curso 1
EXEC dbo.sp_AsignaturasPorCurso @Curso = 1;

-- Prueba NO permitida (crear grupo)
-- Esperado: error de permisos
EXEC dbo.sp_CrearGrupo @IdGrupo = 9, @IdAsignatura = 101, @Curso = 1;

-- Prueba NO permitida (acceso directo a tabla)
-- Esperado: error de permisos
SELECT * FROM Asignaturas.Tb_Asignaturas;

-- ========================================
-- Usuario: profesor
-- ========================================

-- Prueba permitida (crear grupo)
-- Esperado: insercion correcta
EXEC dbo.sp_CrearGrupo @IdGrupo = 10, @IdAsignatura = 101, @Curso = 1;

-- Prueba NO permitida (unirse a grupo)
-- Esperado: error de permisos
EXEC dbo.sp_UnirseAGrupo @IdAlumno = 3, @IdGrupo = 1, @Curso = 1;

-- ========================================
-- Usuario: pec
-- ========================================

-- Prueba permitida (crear grupos automaticos)
-- Esperado: grupos generados para curso 2 y asignatura 102
EXEC dbo.sp_CrearGruposAutomaticos @IdAsignatura = 102, @Curso = 2;

-- Prueba NO permitida (crear grupo manual)
-- Esperado: error de permisos
EXEC dbo.sp_CrearGrupo @IdGrupo = 11, @IdAsignatura = 101, @Curso = 1;


-- ========================================
-- Trigger: tr_BajaAlumnoGrupo
-- ========================================
-- Este trigger se activa cada vez que un alumno es eliminado de un grupo.
-- Inserta el alumno en Tb_Alum_NoGrupo con la asignatura correspondiente y la fecha.

IF OBJECT_ID('Grupos.tr_BajaAlumnoGrupo', 'TR') IS NOT NULL
    DROP TRIGGER Grupos.tr_BajaAlumnoGrupo;
GO

CREATE TRIGGER Grupos.tr_BajaAlumnoGrupo
ON Grupos.Tb_Alum_Grupo
AFTER DELETE
AS
BEGIN
    -- Insertamos en la tabla auxiliar la informacion del alumno eliminado
    INSERT INTO Grupos.Tb_Alum_NoGrupo (IdAlumno, IdAsignatura, FechaSalida)
    SELECT 
        d.IdAlumno,
        g.IdAsignatura,
        GETDATE()
    FROM deleted d
    JOIN Grupos.Tb_Grupos g 
        ON d.IdGrupo = g.IdGrupo AND d.Curso = g.Curso;
END;
GO

PRINT 'Trigger tr_BajaAlumnoGrupo creado correctamente.';
-- ========================================
-- PASO DE PRUEBA: eliminar a un alumno de un grupo
-- ========================================
-- Esto debe activar el trigger y copiar el alumno a Tb_Alum_NoGrupo

-- 1. Eliminar la relacion del alumno con el grupo
DELETE FROM Grupos.Tb_Alum_Grupo
WHERE IdAlumno = 4 AND IdGrupo = 2 AND Curso = 1;
GO

-- 2. Verificar que fue insertado en la tabla de bajas
SELECT * FROM Grupos.Tb_Alum_NoGrupo;
GO
-- ========================================
-- 8.1.1: TABLAS CREADAS POR ESQUEMA//Comprobar tablas creadas por esquema
-- ========================================
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name;
-- ========================================
-- 8.1.2: CLAVES PRIMARIAS//Comprobar claves primarias
-- ========================================
SELECT 
    t.name AS Tabla,
    c.name AS Columna,
    i.name AS Nombre_PK
FROM 
    sys.indexes i
JOIN 
    sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN 
    sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN 
    sys.tables t ON i.object_id = t.object_id
WHERE 
    i.is_primary_key = 1
ORDER BY t.name, i.name;
-- ========================================
-- 8.1.3: CLAVES FORANEAS//	Comprobar claves foraneas
-- ========================================
SELECT 
    fk.name AS FK_Nombre,
    tp.name AS Tabla_Principal,
    tr.name AS Tabla_Referenciada
FROM 
    sys.foreign_keys fk
JOIN 
    sys.tables tp ON fk.parent_object_id = tp.object_id
JOIN 
    sys.tables tr ON fk.referenced_object_id = tr.object_id;
-- ========================================
-- 8.1.4: CHECKS//Comprobar restricciones CHECK
-- ========================================
SELECT 
    t.name AS Tabla,
    c.name AS Columna,
    cc.definition AS Restriccion
FROM 
    sys.check_constraints cc
JOIN 
    sys.columns c ON cc.parent_object_id = c.object_id AND cc.parent_column_id = c.column_id
JOIN 
    sys.tables t ON cc.parent_object_id = t.object_id;
-- ========================================
-- 8.1.5: TRIGGER EXISTENTE//	Comprobar trigger
-- ========================================
SELECT 
    name AS NombreTrigger,
    OBJECT_NAME(parent_id) AS TablaAsociada,
    type_desc AS Tipo
FROM 
    sys.triggers
WHERE 
    name = 'tr_BajaAlumnoGrupo';
-- ========================================
-- 8.1.6: PROCEDIMIENTOS ALMACENADOS// Comprobar procedimientos almacenados
-- ========================================
SELECT 
    name AS NombreProcedimiento,
    type_desc AS TipoObjeto
FROM 
    sys.procedures
WHERE 
    name LIKE 'sp_%';
-- ========================================
-- 8.1.7: CIFRADO ACTIVO//	Comprobar estado del cifrado TDE
-- ========================================
SELECT 
    db.name AS NombreBD,
    dek.encryption_state AS Estado,
    CASE dek.encryption_state
        WHEN 0 THEN 'Sin clave de cifrado'
        WHEN 1 THEN 'Clave creada, cifrado no activado'
        WHEN 2 THEN 'Cifrado en progreso'
        WHEN 3 THEN 'Cifrado activo'
        ELSE 'Otro estado'
    END AS EstadoDescripcion
FROM sys.dm_database_encryption_keys dek
JOIN sys.databases db ON dek.database_id = db.database_id
WHERE db.name = 'PracticaBDA';
-- ========================================
-- 8.2.1: CREACION DEL DISPOSITIVO DE BACKUP//CREAR BACKUP COMPLETO DE LA BASE DE DATOS
-- ========================================
USE master;
GO

EXEC sp_addumpdevice 'disk', 'PracticaBDA_Backup', 'C:\Backup\PracticaBDA.bak';
-- ========================================
-- 8.2.2: BACKUP DE LA BASE DE DATOS//	Realizar backup completo
-- ========================================
BACKUP DATABASE PracticaBDA
TO PracticaBDA_Backup
WITH INIT, FORMAT, NAME = 'Backup Completo PracticaBDA';
GO

PRINT 'Backup completo de PracticaBDA generado correctamente.';
-- ========================================
-- 8.2.3: VERIFICAR ARCHIVO DE BACKUP//	Verificar que el backup es valido
-- ========================================
RESTORE VERIFYONLY FROM PracticaBDA_Backup;
