-- ============================================================================
-- Oracle 19c — Script de configuración inicial (ejecutado una sola vez).
-- Se ejecuta como SYSDBA sobre el CDB, después de la creación de la base.
-- ============================================================================

-- Auto-abrir todas las PDBs en cada arranque de la instancia.
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;

EXIT;
