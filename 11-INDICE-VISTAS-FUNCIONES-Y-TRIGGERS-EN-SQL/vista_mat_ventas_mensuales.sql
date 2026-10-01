CREATE MATERIALIZED VIEW vista_mat_ventas_mensuales AS
SELECT 
    DATE_TRUNC('month', p.fecha_pedido) AS mes,
    COUNT(DISTINCT p.id) AS total_pedidos,
    COUNT(DISTINCT p.cliente_id) AS clientes_unicos,
    SUM(dp.cantidad) AS libros_vendidos,
    COUNT(DISTINCT dp.libro_id) AS titulos_diferentes,
    SUM(p.subtotal) AS ingresos_brutos,
    SUM(p.impuestos) AS total_impuestos,
    SUM(p.gastos_envio) AS total_envios,
    SUM(p.total) AS ingresos_totales,
    AVG(p.total) AS ticket_promedio,
    MAX(p.total) AS pedido_mas_grande,
    COUNT(CASE WHEN p.estado = 'cancelado' THEN 1 END) AS pedidos_cancelados,
    ROUND(
        COUNT(CASE WHEN p.estado = 'cancelado' THEN 1 END)::NUMERIC / 
        COUNT(*)::NUMERIC * 100, 
        2
    ) AS porcentaje_cancelacion
FROM pedidos p
JOIN detalles_pedido dp ON p.id = dp.pedido_id
WHERE p.estado IN ('entregado', 'cancelado')
GROUP BY DATE_TRUNC('month', p.fecha_pedido)
ORDER BY mes DESC;