DROP TABLE detalle_pedido CASCADE CONSTRAINTS;
DROP TABLE pedidos CASCADE CONSTRAINTS;
DROP TABLE platos CASCADE CONSTRAINTS;
DROP TABLE personal_servicio CASCADE CONSTRAINTS;
DROP TABLE clientes CASCADE CONSTRAINTS;

DROP SEQUENCE seq_pedidos;


-- Creación de tablas y secuencias



create sequence seq_pedidos;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    telefono VARCHAR2(20)
);

CREATE TABLE personal_servicio (
    id_personal INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    pedidos_activos INTEGER DEFAULT 0 CHECK (pedidos_activos <= 5)
);

CREATE TABLE platos (
    id_plato INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponible INTEGER DEFAULT 1 CHECK (DISPONIBLE in (0,1))
);

CREATE TABLE pedidos (
    id_pedido INTEGER PRIMARY KEY,
    id_cliente INTEGER REFERENCES clientes(id_cliente),
    id_personal INTEGER REFERENCES personal_servicio(id_personal),
    fecha_pedido DATE DEFAULT SYSDATE,
    total DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    id_plato INTEGER REFERENCES platos(id_plato),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (id_pedido, id_plato)
);


	
-- Procedimiento a implementar para realizar la reserva
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
    v_disponiblePrimerPlato INTEGER;
    v_disponibleSegundoPlato INTEGER;
    v_pedidosActivos INTEGER;
    v_id_pedido INTEGER;
    v_idCliente INTEGER;
    v_precioPrimerPlato DECIMAL(10, 2);
    v_precioSegundoPlato DECIMAL(10, 2);
    v_precioTotal DECIMAL(10, 2);
 begin

    --Comprueba si el cliente existe
    if arg_id_cliente is null then
        raise_application_error(-20005, 'El cliente no existe.');
    else
        select count(*) into v_idCliente
        from clientes
        where id_cliente = arg_id_cliente;

        if v_idCliente = 0 then
            raise_application_error(-20005, 'El cliente no existe.');
        end if;
    end if;
    
    -- Comprueba si no se ha definido al menos un plato
    if arg_id_primer_plato is null and arg_id_segundo_plato is null then
        raise_application_error(-20002, 'El pedido deber contener al menos un plato.');
    end if;

    v_precioTotal := 0;
    -- Comprueba si el primer plato existe
    if arg_id_primer_plato is not null then
        begin
            SELECT precio, disponible INTO v_precioPrimerPlato, v_disponiblePrimerPlato
            from platos
            where id_plato = arg_id_primer_plato
            for update;
            
            if v_disponiblePrimerPlato = 0 then
                raise_application_error(-20001, 'El primer plato seleccionado no está disponible.');
            end if;

            v_precioTotal := v_precioTotal + v_precioPrimerPlato;

        exception
            when no_data_found then
                raise_application_error(-20004, 'El primer plato seleccionado no existe');
        end;
    end if;

    -- Comprueba si el segundo plato existe
    if arg_id_segundo_plato is not null then
        begin
            SELECT precio, disponible INTO v_precioSegundoPlato, v_disponibleSegundoPlato
            from platos
            where id_plato = arg_id_segundo_plato
            for update;
            
            if v_disponibleSegundoPlato = 0 then
                raise_application_error(-20001, 'El segundo plato seleccionado no está disponible.');
            end if;
            v_precioTotal := v_precioTotal + v_precioSegundoPlato;
        exception
            when no_data_found then
                raise_application_error(-20004, 'El segundo plato seleccionado no existe');
        end;
    end if;

    -- Verificar si el personal de servicio tiene menos de 5 pedidos activos
    SELECT pedidos_activos INTO v_pedidosActivos    
    from personal_servicio
    where id_personal = arg_id_personal
    for update;
    if v_pedidosActivos >= 5 then
        raise_application_error(-20003, 'El personal de servicio tiene demasiados pedidos.');
    end if;

    -- Registrar el pedido
    select seq_pedidos.nextval into v_id_pedido from dual;
    insert into pedidos (id_pedido, id_cliente, id_personal, total) values (v_id_pedido, arg_id_cliente, arg_id_personal, v_precioTotal);

    -- Registrar detalles del pedido
    if arg_id_primer_plato is not null then
        insert into detalle_pedido (id_pedido, id_plato, cantidad) values (v_id_pedido, arg_id_primer_plato, 1);
    end if;
    if arg_id_segundo_plato is not null then
        insert into detalle_pedido (id_pedido, id_plato, cantidad) values (v_id_pedido, arg_id_segundo_plato, 1);
    end if;

    -- Actualiza los pedidos activos del personal de servicio
    update personal_servicio
    set pedidos_activos = pedidos_activos + 1
    where id_personal = arg_id_personal;

    commit;
exception
    when others then
        rollback;
        raise;
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- NO SE CORREGIRÁN RESPUESTAS QUE NO ESTÉN AQUÍ (utiliza el espacio que necesites apra cada una)
-- * P4.1 Para asegurar que un miembro del personal no supere el límite de 5 pedidos activos,
-- consulto el número de pedidos que ya tiene asignados y comparo si es menor que 5.
-- Si ya tiene 5 pedidos, lanzo una excepción controlada con el código -20003.
-- Esto evita que se le asignen más pedidos de los permitidos.

-- * P4.2 Para evitar condiciones de carrera en transacciones concurrentes,
-- uso la cláusula SELECT ... FOR UPDATE para bloquear la fila del personal.
-- Así garantizo que mientras una transacción actualiza los pedidos activos,
-- otra no pueda hacerlo hasta que la primera termine, evitando inconsistencias.

-- * P4.3 Sí, se puede asegurar usando una transacción completa (BEGIN ... COMMIT).
-- Si ocurre un error en cualquiera de los pasos (insertar pedido, detalles o actualizar personal),
-- uso ROLLBACK para deshacer todo. De esta manera evito que queden datos a medias.

-- * P4.4 Si se añade un CHECK que limita los pedidos activos a 5 directamente en la tabla,
-- podría saltar un error de integridad al intentar actualizar la tabla sin necesidad de hacer una comprobación manual.
-- En ese caso, tendría que capturar el error SQL correspondiente (por ejemplo, con OTHERS)
-- y traducirlo a un mensaje más claro para el usuario, como el del error -20003.
-- También podría dejar la validación lógica previa, para dar mensajes más controlados.

-- * P4.5 He utilizado una estrategia defensiva, controlando todos los posibles errores con excepciones personalizadas.
-- Esto se ve en el uso de bloques IF con condiciones, y en la parte EXCEPTION del procedimiento,
-- donde capturo errores y devuelvo mensajes claros según cada situación específica.
-- También uso transacciones para asegurar la atomicidad del proceso.

create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
    DBMS_OUTPUT.PUT_LINE('Inicializando test');

    reset_seq('seq_pedidos');
  
    delete from Detalle_pedido;
    delete from Pedidos;
    delete from Platos;
    delete from Personal_servicio;
    delete from Clientes;
    
    -- Insertar datos de prueba
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (1, 'Pepe', 'Perez', '123456789');
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (2, 'Ana', 'Garcia', '987654321');
    
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (1, 'Carlos', 'Lopez', 0);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (2, 'Maria', 'Fernandez', 5);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (3, 'Jose', 'Manuel', 0);
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, 0);

    commit;
end;
/

--exec inicializa_test;

-- Completa lost test, incluyendo al menos los del enunciado y añadiendo los que consideres necesarios

create or replace procedure test_registrar_pedido is
begin
	DBMS_OUTPUT.PUT_LINE('Empieza test');
    
    begin
        inicializa_test;
    end;
  -- Idem para el resto de casos

  /* - Si se realiza un pedido vacıo (sin platos) devuelve el error -200002.
     - Si se realiza un pedido con un plato que no existe devuelve en error -20004.
     - Si se realiza un pedido que incluye un plato que no est´a ya disponible devuelve el error -20001.
     - Personal de servicio ya tiene 5 pedidos activos y se le asigna otro pedido devuelve el error -20003
     - ... los que os puedan ocurrir que puedan ser necesarios para comprobar el correcto funcionamiento del procedimiento
*/
    
    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 1: Pedidos válidos con platos validos.');
        DBMS_OUTPUT.PUT_LINE('El cliente 1, el personal 1 realiza el primer plato 1 y el segundo plato 2');
        DBMS_OUTPUT.PUT_LINE('El cliente 1, el personal 3 realiza el primer plato 1 y el segundo plato 2');
        registrar_pedido(1, 1, 1, 2); 
        registrar_pedido(1, 3, 1, 2); 
        
        -- Muestra los información del pedido
        DBMS_OUTPUT.PUT_LINE('-Información de los pedidos-');
        FOR rec IN (SELECT * FROM pedidos WHERE id_pedido = 1 or id_pedido = 2) LOOP
            DBMS_OUTPUT.PUT_LINE('Pedido: ' || rec.id_pedido || ', Cliente: ' || rec.id_cliente || ', Personal: ' || rec.id_personal);
        END LOOP;
        
        -- Muestra los detalles del pedido
        FOR rec IN (SELECT * FROM detalle_pedido WHERE id_pedido = 1 or id_pedido = 2) LOOP
            DBMS_OUTPUT.PUT_LINE('Plato ID: ' || rec.id_plato || ', Cantidad: ' || rec.cantidad);
        END LOOP;
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;
        

    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 2: Pedido vacio, sin platos');
        registrar_pedido(2, 1, null, null); 
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;


    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 3.1: Pedido con plato el primer plato no existente');
        registrar_pedido(1, 1, 999, 2);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;

    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 3.2: Pedido con plato el segundo plato no existente');
        registrar_pedido(1, 1, 2, 999);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;


    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 4.1: Pedido con el primer plato no disponible');
        registrar_pedido(1, 1, 3, 1);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;

    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 4.2: Pedido con el segundo plato no disponible');
        registrar_pedido(1, 1, 1, 3);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;


    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 5: Personal de servicio con 5 pedidos activos');
        registrar_pedido(1, 2, 1, 2);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;

    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 6.1: Cliente inexistente. identificador nulo');
        registrar_pedido(NULL, 2, 1, NULL);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;

    begin
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Prueba 6.2: Cliente inexistente. identificador incorrecto');
        registrar_pedido(999, 2, 1, 2);
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
    end;
end;
/


set serveroutput on;
exec test_registrar_pedido;