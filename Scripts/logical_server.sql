-- Tablas que se van a subscribir 
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


-- Crear susbscripcion
create subscription subscription 
	connection 'host=localhost port=5432 dbname=athleticrace user=rol_replica_logica password=1234'
	publication publication;

-- Prueba de sincronizacion de datos
SELECT * FROM Carrera;
