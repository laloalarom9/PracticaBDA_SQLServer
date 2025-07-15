# 🗃️ Práctica SQL Server - Gestión de Base de Datos con TDE, Particiones y Procedimientos

Este repositorio contiene el script completo de la práctica **"PracticaBDA"**, desarrollada en **SQL Server 2016**. Incluye diseño, cifrado, particiones, creación de tablas, inserciones, vistas, procedimientos almacenados, triggers, seguridad y backup.

---

## 📌 Contenidos principales

- 📦 **Creación de la base de datos `PracticaBDA`**
- 🔐 **Cifrado TDE (Transparent Data Encryption)**
- 📁 **Filegroups y archivos `.ndf`**
- 📊 **Particionado horizontal de la tabla `Grupos.Tb_Grupos` por curso**
- 🧾 **Esquemas lógicos: Alumnos, Asignaturas, Grupos y Evaluación**
- 🧱 **Tablas relacionales con claves primarias, foráneas y restricciones**
- 🔄 **Procedimientos almacenados para gestión dinámica**
- 🧠 **Trigger para auditoría de bajas de alumnos**
- 👥 **Creación de usuarios y asignación de permisos**
- 🧯 **Backup cifrado y verificación del mismo**

---

## 📂 Estructura

```sql
-- PASO 1: Configuración general y cifrado TDE
-- PASO 2: Particionado, filegroups y esquemas
-- PASO 3: Creación de tablas
-- PASO 4: Inserción de datos de prueba
-- PASO 5: Vistas de consulta
-- PASO 6: Procedimientos almacenados (alta, consulta, unión a grupo)
-- PASO 7: Trigger de auditoría
-- PASO 8: Verificaciones y backup completo
```

---

## ⚙️ Requisitos

- SQL Server 2016 o superior (Enterprise para TDE y particiones)
- Ruta `C:\Datos` y `C:\Backup` existentes (o modifica en el script)
- Ejecutar el script por bloques (`GO`) en SQL Server Management Studio (SSMS)

---

## 🧪 Verificación incluida

Al final del script se incluyen consultas para verificar:

- Tablas, claves primarias y foráneas
- Restricciones `CHECK`
- Trigger activo
- Procedimientos creados
- Cifrado activo
- Backup válido

---

## 👨‍💻 Autor

**Eduardo Alarcón**  
Estudiante de Ingeniería Informática - Universidad Francisco de Vitoria (UFV)  

