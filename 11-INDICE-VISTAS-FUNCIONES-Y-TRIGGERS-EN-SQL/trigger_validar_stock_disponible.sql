CREATE OR REPLACE FUNCTION trigger_validar_stock_disponible()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_actual INTEGER;
    v_titulo VARCHAR;
BEGIN
    -- Obtener stock actual y título
    SELECT stock, titulo 
    INTO v_stock_actual, v_titulo
    FROM libros
    WHERE id = NEW.libro_id;
    
    -- Si es un UPDATE, considerar la cantidad anterior
    IF TG_OP = 'UPDATE' THEN
        v_stock_actual := v_stock_actual + OLD.cantidad;
    END IF;
    
    -- Validar disponibilidad
    IF v_stock_actual < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para "%". Disponible: %, Solicitado: %',
                       v_titulo, v_stock_actual, NEW.cantidad;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_stock_antes_detalle
    BEFORE INSERT OR UPDATE ON detalles_pedido
    FOR EACH ROW
    EXECUTE FUNCTION trigger_validar_stock_disponible();