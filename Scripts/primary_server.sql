-- Estructura de la base de datos

CREATE TABLE Carrera (
    id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    lugar VARCHAR(255) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    costo_entrada DECIMAL(10, 2) NOT NULL
);

CREATE TABLE Patrocinador (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL
);

CREATE TABLE Participante (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    edad INT NOT NULL,
    genero VARCHAR(50)
);

CREATE TABLE Premio (
    id SERIAL PRIMARY KEY,
    descripcion TEXT NOT NULL,
    patrocinador_id INT,
    carrera_id INT,
    FOREIGN KEY (patrocinador_id) REFERENCES Patrocinador(ID),
    FOREIGN KEY (carrera_id) REFERENCES Carrera(ID)
);

CREATE TABLE Chat (
    id SERIAL PRIMARY KEY,
    p1 INT NOT NULL,
    p2 INT NOT NULL,
    UNIQUE (p1, p2)
);

ALTER TABLE Chat
ADD CONSTRAINT fk_chat_p1 FOREIGN KEY (p1) REFERENCES Participante(id),
ADD CONSTRAINT fk_chat_p2 FOREIGN KEY (p2) REFERENCES Participante(id);

CREATE TABLE Mensaje (
    id SERIAL PRIMARY KEY,
    mensaje TEXT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_chat INT NOT NULL,
    FOREIGN KEY (id_chat) REFERENCES Chat(id)
);

CREATE TABLE ParticipanteStats (
    duracion TIME NOT NULL,
    numero_de_puesto INT NOT NULL,
    carrera INT NOT NULL,
    participante INT NOT NULL,
    premio INT,
    PRIMARY KEY (carrera, participante),
    FOREIGN KEY (carrera) REFERENCES Carrera(id),
    FOREIGN KEY (participante) REFERENCES Participante(id),
    FOREIGN KEY (premio) REFERENCES Premio(id)
);

-- Roles 
-- Rol principal 
create role rol_primario with login superuser password '1234';

-- Rol replica fisica
create role rol_replica_fisica with replication login password '1234';
grant all privileges on database postgres to rol_replica_fisica;
grant all privileges on all tables in schema public to rol_replica_fisica;

-- Rol replica logica
create role rol_replica_logica with replication login password '1234';
grant all privileges on database athleticrace to rol_replica_logica;
grant all privileges on all tables in schema public to rol_replica_logica;

-- Creacion de los publicadores 
CREATE PUBLICATION publication;

ALTER PUBLICATION publication ADD TABLE Carrera;
ALTER PUBLICATION publication ADD TABLE Patrocinador;
ALTER PUBLICATION publication ADD TABLE Participante;
ALTER PUBLICATION publication ADD TABLE Chat;
ALTER PUBLICATION publication ADD TABLE Premio;
ALTER PUBLICATION publication ADD TABLE Mensaje;
ALTER PUBLICATION publication ADD TABLE ParticipanteStats;

-- Funciones
-- Mostrar el historial de tiempos de un participante 
CREATE OR REPLACE FUNCTION obtener_historial_participante(p_participante_id INT)
RETURNS TABLE (
    carrera INT,
    duracion TIME,
    numero_de_puesto INT,
    premio INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ps.carrera,
        ps.duracion,
        ps.numero_de_puesto,
        ps.premio
    FROM 
        ParticipanteStats AS ps
    WHERE 
        ps.participante = p_participante_id;
END;
$$ LANGUAGE plpgsql;

-- Obtener detalles de carrera, como tal lo complejo de obtener son sus patrocinadores, por eso la funcion
CREATE OR REPLACE FUNCTION obtener_patrocinadores_carrera(p_carrera_id INT)
RETURNS TABLE (
    patrocinador_nombre VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT 
        pat.nombre AS patrocinador_nombre
    FROM 
        Premio pr
    JOIN 
        Patrocinador pat ON pr.patrocinador_id = pat.id
    WHERE 
        pr.carrera_id = p_carrera_id;
END;
$$ LANGUAGE plpgsql;

-- Insertar mensajes, obtiene el id de dos participantes e inserta un mensaje en el chat de ellos 
CREATE OR REPLACE FUNCTION insertar_mensaje_chat(
    p_participante1_id INT,
    p_participante2_id INT,
    p_mensaje TEXT
) RETURNS VOID AS $$
DECLARE
    chat_id INT;
BEGIN
    SELECT id INTO chat_id
    FROM Chat
    WHERE (p1 = p_participante1_id AND p2 = p_participante2_id)
       OR (p1 = p_participante2_id AND p2 = p_participante1_id)
    LIMIT 1;

    IF chat_id IS NULL THEN
        RAISE EXCEPTION 'No existe un chat entre los participantes % y %', p_participante1_id, p_participante2_id;
    END IF;

    INSERT INTO Mensaje (mensaje, id_chat)
    VALUES (p_mensaje, chat_id);
END;
$$ LANGUAGE plpgsql;

-- Obtener todos los mensajes entre dos personas 
CREATE OR REPLACE FUNCTION obtener_mensajes_chat(
    p_participante1_id INT,
    p_participante2_id INT
) RETURNS TABLE (
    mensaje TEXT,
    fecha TIMESTAMP
) AS $$
DECLARE
    chat_id INT;
BEGIN
    SELECT id INTO chat_id
    FROM Chat
    WHERE (p1 = p_participante1_id AND p2 = p_participante2_id)
       OR (p1 = p_participante2_id AND p2 = p_participante1_id)
    LIMIT 1;

    IF chat_id IS NULL THEN
        RAISE EXCEPTION 'No existe un chat entre los participantes % y %', p_participante1_id, p_participante2_id;
    END IF;

    RETURN QUERY
    SELECT 
        m.mensaje,
        m.fecha
    FROM 
        Mensaje m
    WHERE 
        m.id_chat = chat_id
    ORDER BY 
        m.fecha;
END;
$$ LANGUAGE plpgsql;

--Inserts de prueba 
INSERT INTO Carrera (fecha, lugar, categoria, costo_entrada) 
VALUES ('2024-11-15', 'Circuito de la Ciudad', 'Juvenil', 150.00);

INSERT INTO Patrocinador (nombre) 
VALUES ('Empresa A'), ('Corporación B');

INSERT INTO Participante (nombre, edad, genero) 
VALUES 
    ('Carlos Pérez', 20, 'Masculino'),
    ('Ana Gómez', 22, 'Femenino'),
    ('Luis García', 19, 'Masculino');

INSERT INTO Premio (descripcion, patrocinador_id, carrera_id)
VALUES 
    ('TV Samsung', 1, 1),
    ('Refrigeradora', 2, 1);

INSERT INTO Chat (p1, p2) 
VALUES 
    (1, 2),
    (1, 3),
    (2, 3);

INSERT INTO Mensaje (mensaje, id_chat) 
VALUES 
    ('Hola, ¿cómo estás?', 1),
    ('Todo bien, ¿y tú?', 1),
    ('Hola Ana', 2),
    ('Hola Luis', 3),
    ('¿Listo para la carrera?', 1);

INSERT INTO ParticipanteStats (duracion, numero_de_puesto, carrera, participante, premio)
VALUES 
    ('00:45:30', 1, 1, 1, 1),
    ('00:47:20', 2, 1, 2, 2),
    ('00:49:10', 3, 1, 3, NULL);

-- Test de la funcion de insertar mensajes, no se puede ejecutar del backup porqe es insert
SELECT insertar_mensaje_chat(1, 2, 'Mensaje de prueba usando la funcion');

SELECT * FROM Carrera;
SELECT * FROM Participante;
SELECT * FROM Patrocinador
SELECT obtener_historial_participante(1);
SELECT obtener_patrocinadores_carrera(1);
SELECT * FROM obtener_mensajes_chat(1, 2);

SELECT * FROM pg_available_extensions WHERE name = 'pg_cron';
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Creacion de los Jobs 
-- Primer JOB: Job de Sincronización y Limpieza de Mensajes de Chat
CREATE TABLE LogLimpiezaMensajes (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    mensajes_eliminados INT,
    descripcion VARCHAR(255)
);

CREATE OR REPLACE FUNCTION limpiar_mensajes_antiguos()
RETURNS VOID AS $$
DECLARE
    mensajes_eliminados INT;
BEGIN
    DELETE FROM Mensaje
    WHERE fecha < NOW() - INTERVAL '30 days'
    RETURNING id INTO mensajes_eliminados;

    INSERT INTO LogLimpiezaMensajes (mensajes_eliminados, descripcion)
    VALUES (mensajes_eliminados, 'Limpieza exitosa de mensajes antiguos');

    RAISE NOTICE 'Se han eliminado % mensajes antiguos.', mensajes_eliminados;
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO LogLimpiezaMensajes (mensajes_eliminados, descripcion)
        VALUES (NULL, 'Error al intentar eliminar mensajes: ' || SQLERRM);
        RAISE WARNING 'Error al intentar eliminar mensajes antiguos: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

SELECT cron.schedule(
    'limpiar_mensajes_antiguos_job',
    '0 0 * * *',  -- Se ejecuta a medianoche todos los días
    'SELECT limpiar_mensajes_antiguos();'
);

-- Segundo JOB: Job de Actualización de Estadísticas de Carreras 
-- Como tal se tenia que hacer en el servidor secundario, pero se hace en el primario para 
-- que se propague al secundario
CREATE TABLE EstadisticasCarreras (
    carrera_id INT PRIMARY KEY,
    total_participantes INT NOT NULL,
    tiempo_promedio INTERVAL NOT NULL
);

CREATE TABLE JobLog (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    carrera_id INT,
    mensaje TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION actualizar_estadisticas_carreras()
RETURNS VOID AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT carrera, COUNT(participante) AS total_participantes, AVG(duracion) AS tiempo_promedio
        FROM ParticipanteStats
        GROUP BY carrera
    LOOP
        BEGIN
            INSERT INTO EstadisticasCarreras (carrera_id, total_participantes, tiempo_promedio)
            VALUES (rec.carrera, rec.total_participantes, rec.tiempo_promedio)
            ON CONFLICT (carrera_id) DO UPDATE
            SET total_participantes = EXCLUDED.total_participantes,
                tiempo_promedio = EXCLUDED.tiempo_promedio;

            INSERT INTO JobLog (fecha, carrera_id, mensaje)
            VALUES (NOW(), rec.carrera, 'Estadísticas actualizadas correctamente');
        EXCEPTION WHEN OTHERS THEN
            INSERT INTO JobLog (fecha, carrera_id, mensaje)
            VALUES (NOW(), rec.carrera, 'Error al actualizar estadísticas: ' || SQLERRM);
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT cron.schedule(
    'Actualizacion de Estadisticas de Carreras',
    '0 0 * * 0',  -- Todos los domingos a medianoche
    $$
    SELECT actualizar_estadisticas_carreras();
    $$
);

-- Tercer JOB: 
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE OR REPLACE FUNCTION sync_patrocinadores_y_premios()
RETURNS VOID AS $$
BEGIN
    PERFORM dblink_exec(
        'host=localhost port=5434 dbname=athleticrace user=rol_replica_logica password=1234',
        'INSERT INTO Patrocinador (id, nombre)
         SELECT id, nombre FROM Patrocinador
         ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;'
    );

    PERFORM dblink_exec(
        'host=localhost port=5434 dbname=athleticrace user=rol_replica_logica password=1234',
        'INSERT INTO Premio (id, descripcion, patrocinador_id, carrera_id)
         SELECT id, descripcion, patrocinador_id, carrera_id FROM Premio
         ON CONFLICT (id) DO UPDATE SET
         descripcion = EXCLUDED.descripcion,
         patrocinador_id = EXCLUDED.patrocinador_id,
         carrera_id = EXCLUDED.carrera_id;'
    );
END;
$$ LANGUAGE plpgsql;

SELECT cron.schedule(
    'sync_patrocinadores_y_premios_job',
    '0 */6 * * *',
    'SELECT sync_patrocinadores_y_premios();'
);

SELECT jobid, schedule, jobname
FROM cron.job;
