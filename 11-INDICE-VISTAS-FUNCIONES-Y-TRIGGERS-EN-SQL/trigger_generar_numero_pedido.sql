-- Función
CREATE OR REPLACE FUNCTION trigger_generar_numero_pedido()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo generar si no se proporcionó número
    IF NEW.numero_pedido IS NULL OR NEW.numero_pedido = '' THEN
        NEW.numero_pedido := 'P-' || 
                            TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || 
                            LPAD(
                                (SELECT COALESCE(COUNT(*), 0) + 1 
                                 FROM pedidos 
                                 WHERE EXTRACT(YEAR FROM fecha_pedido) = EXTRACT(YEAR FROM CURRENT_DATE))::TEXT,
                                5, '0'
                            );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_antes_insertar_pedido
    BEFORE INSERT ON pedidos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_generar_numero_pedido();