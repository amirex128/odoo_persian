# راهنمای جامع تنظیمات و عملیات Odoo 19

این سند راهنمای عملیاتی پروژهٔ حاضر است و بر پایهٔ مستندات رسمی Odoo 19 تنظیم شده است. در این پروژه، Odoo داخل image اجرا می‌شود و PostgreSQL باید به‌صورت سرویس جداگانه، managed یا PostgreSQL مبتنی بر pgvector ارائه شود.

## 1. معماری و جریان راه‌اندازی

Odoo یک application server است که به یک database PostgreSQL متصل می‌شود. فایل `config/odoo.conf` تنظیمات غیرحساس را نگه می‌دارد و secretها در runtime از Environment/Secrets سرویس دریافت می‌شوند. `entrypoint.sh` قبل از اجرای Odoo، volume را آماده می‌کند، config runtime می‌سازد، نام‌های `POSTGRES_*` را به نام‌های رسمی image یعنی `HOST`, `PORT`, `USER`, `PASSWORD` نگاشت می‌کند و سپس Odoo را با کاربر غیرroot اجرا می‌کند.

| جزء | مقدار پروژه | مسئولیت |
|---|---|---|
| Odoo HTTP | `8069` | وب، API و رابط کاربری |
| Odoo gevent/live bus | `8072` | longpolling و bus در deploymentهای چند worker |
| addons | `/mnt/extra-addons` | addonهای OCA و سفارشی |
| data directory | `/var/lib/odoo` | filestore، session و داده‌های runtime |
| PostgreSQL | سرویس خارجی در PaaS | database و transactionها |

## 2. ساخت role PostgreSQL

برای محیطی که به PostgreSQL administrator دسترسی دارید، role مخصوص Odoo را با حداقل مجوز لازم بسازید. رمز را در shell history یا Git قرار ندهید و مقدار واقعی را جایگزین placeholder کنید:

```bash
psql -h <POSTGRES_HOST> -p <POSTGRES_PORT> -U <POSTGRES_ADMIN_USER> -d postgres
```

سپس در psql:

```sql
CREATE ROLE odoo LOGIN PASSWORD '<POSTGRES_PASSWORD>' CREATEDB;
```

اگر role از قبل وجود دارد:

```sql
ALTER ROLE odoo WITH LOGIN PASSWORD '<POSTGRES_PASSWORD>';
```

برای اتصال به database موجود، مالکیت و مجوزها را بررسی کنید:

```sql
ALTER DATABASE <ODOO_DATABASE> OWNER TO odoo;
GRANT CONNECT ON DATABASE <ODOO_DATABASE> TO odoo;
```

طبق مستندات Odoo، database manager برای ساخت database به مجوز `createdb` نیاز دارد [1]. در production که database manager غیرفعال است، می‌توان مجوزهای مدیریتی را محدودتر کرد؛ role کاربردی Odoo نباید superuser باشد.

## 3. نصب pgvector در PostgreSQL PaaS

pgvector یک extension در سطح PostgreSQL است و باید در **هر databaseای که قرار است از vector استفاده کند** یک‌بار فعال شود [3]. اگر PaaS image یا extension را از قبل ارائه می‌کند:

```bash
psql -h <POSTGRES_HOST> -p <POSTGRES_PORT> \
  -U <POSTGRES_ADMIN_USER> -d <ODOO_DATABASE>
```

```sql
CREATE EXTENSION IF NOT EXISTS vector;
SELECT extversion FROM pg_extension WHERE extname = 'vector';
```

برای Docker Compose این repository از image زیر استفاده می‌کند:

```text
pgvector/pgvector:0.8.6-pg18-trixie
```

نمونهٔ اجرای PostgreSQL با volume صحیح برای PostgreSQL 18+:

```bash
docker run -d --name odoo-postgres \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=odoo \
  -e POSTGRES_PASSWORD='<POSTGRES_PASSWORD>' \
  -v postgres-data:/var/lib/postgresql \
  pgvector/pgvector:0.8.6-pg18-trixie
```

سپس extension را در database هدف بسازید. مسیر mount والد `/var/lib/postgresql` برای imageهای PostgreSQL 18+ مهم است، زیرا data directory به‌صورت major-version-specific مدیریت می‌شود. اگر PaaS امکان نصب extension را نمی‌دهد، نمی‌توان از SQL صرفاً برای نصب آن استفاده کرد؛ باید plan/image سرویس قابلیت pgvector داشته باشد.

## 4. متغیرهای محیطی PaaS

فایل `.env.paas.example` فقط template است. مقادیر واقعی را در Secrets سرویس ثبت کنید:

| متغیر | اجباری | توضیح |
|---|---:|---|
| `POSTGRES_HOST` یا `HOST` | بله | DNS/private hostname یا IP سرویس PostgreSQL |
| `POSTGRES_PORT` یا `PORT` | بله | معمولاً `5432` |
| `POSTGRES_USER` یا `USER` | بله | role واقعی PostgreSQL، مثلاً `odoo` |
| `POSTGRES_PASSWORD` یا `PASSWORD` | بله | password همان role؛ با master password Odoo متفاوت است |
| `ODOO_ADMIN_PASSWD` | بله | password محافظ database manager |
| `ODOO_LIST_DB` | توصیه می‌شود `False` | در production فهرست databaseها را پنهان می‌کند |

نمونهٔ امن:

```text
POSTGRES_HOST=database-iwo-service
POSTGRES_PORT=5432
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<password-of-role-odoo>
ODOO_ADMIN_PASSWD=<separate-odoo-master-password>
ODOO_LIST_DB=False
```

خطای `password authentication failed` به معنی درست‌بودن host/port و نادرست‌بودن credential است. تغییر `POSTGRES_PASSWORD` در Environment بعد از initialize شدن volume الزاماً password role موجود را تغییر نمی‌دهد؛ در این حالت باید `ALTER ROLE` اجرا شود یا secret با password فعلی database یکسان شود.

## 5. فایل `odoo.conf`

تنظیمات مهم پروژه عبارت‌اند از:

```ini
[options]
admin_passwd = <runtime-secret>
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo
proxy_mode = True
list_db = False
http_port = 8069
gevent_port = 8072
```

`admin_passwd` فقط برای database management است و با password کاربر PostgreSQL تفاوت دارد. Odoo توصیه می‌کند مقدار آن تصادفی و قوی باشد و دسترسی به database manager پس از setup محدود شود [1]. `addons_path` باید هم مسیر addonهای core و هم مسیر addonهای پروژه را شامل شود.

### dbfilter و چند database

Odoo می‌تواند چند database را روی یک instance سرو کند. در production چندمستاجری، database را با regular expression محدود کنید:

```ini
dbfilter = ^my_database_name$
```

یا برای mapping بر اساس hostname، الگوی مناسب deployment خود را تعریف کنید. برای یک database مشخص می‌توان از CLI نیز استفاده کرد:

```bash
odoo --config=/etc/odoo/odoo.conf -d my_database
```

بدون `dbfilter` مناسب، وقتی `list_db=False` است، کاربر ممکن است database manager disabled ببیند یا Odoo نتواند database مورد انتظار را از hostname تشخیص دهد.

## 6. راه‌اندازی و volumeها

برای PaaS فقط Dockerfile build می‌شود و PostgreSQL در سرویس جدا قرار دارد. volume ضروری Odoo:

```text
/var/lib/odoo
```

این volume شامل filestore و sessionهاست. entrypoint پروژه در startup اگر volume با مالکیت `root:root` mount شده باشد، پوشهٔ session را می‌سازد و مالکیت را به `odoo:odoo` تغییر می‌دهد. mount کردن `/etc/odoo` توصیه نمی‌شود، چون می‌تواند config داخل image را بپوشاند.

برای Compose:

```bash
cp .env.compose.example .env
# مقدارهای password را تغییر دهید
docker compose --env-file .env up -d --build
docker compose --env-file .env ps
docker compose --env-file .env logs -f odoo
```

## 7. reverse proxy و HTTPS

در production بهتر است TLS در reverse proxy یا خود PaaS terminate شود و traffic داخلی به پورت 8069 برسد. چون پروژه `proxy_mode=True` دارد، reverse proxy باید headerهای استاندارد مانند `X-Forwarded-Proto` و `X-Forwarded-Host` را صحیح ارسال کند. پورت 8072 را فقط در صورت نیاز live bus publish کنید.

## 8. workers و resource limits

برای production پرترافیک، Odoo از workerهای prefork و gevent استفاده می‌کند. تعداد worker به CPU، RAM و نوع workload بستگی دارد و باید با load test تعیین شود. هر worker حافظه مصرف می‌کند؛ memory limits پروژه را با ظرفیت PaaS هماهنگ کنید. برای محیط development معمولاً worker پیش‌فرض کافی است.

## 9. database manager و امنیت

وقتی `ODOO_LIST_DB=False` است، مسیرهای database manager مانند `/web/database/manager` عمداً غیرفعال‌اند. این رفتار خطا نیست. برای setup موقت می‌توان مقدار را `True` کرد، database را ساخت و بعد دوباره `False` کرد. در production علاوه بر این، دسترسی endpointهای مدیریتی را در reverse proxy محدود کنید.

## 10. backup و restore

Backup باید شامل دو بخش باشد: dump PostgreSQL و filestore در `/var/lib/odoo`. نمونهٔ dump:

```bash
pg_dump -h <POSTGRES_HOST> -p <POSTGRES_PORT> \
  -U odoo -Fc -d <ODOO_DATABASE> > odoo.dump
```

Restore:

```bash
createdb -h <POSTGRES_HOST> -p <POSTGRES_PORT> -U odoo <ODOO_DATABASE>
pg_restore -h <POSTGRES_HOST> -p <POSTGRES_PORT> -U odoo \
  -d <ODOO_DATABASE> --clean --if-exists odoo.dump
```

فایل‌های filestore باید هم‌زمان با dump مربوط به همان database نگهداری شوند. volume جایگزین backup نیست.

## 11. عیب‌یابی سریع

| خطا | علت محتمل | اقدام |
|---|---|---|
| `password authentication failed` | password role با secret متفاوت است | `ALTER ROLE` یا اصلاح secret |
| `could not translate host name` | DNS/private network نادرست است | hostname سرویس PaaS را بررسی کنید |
| `connection refused` | port/service/firewall نادرست است | وضعیت PostgreSQL و port را بررسی کنید |
| `database manager disabled` | `ODOO_LIST_DB=False` | برای setup موقت True، برای production False |
| `PermissionError /var/lib/odoo/sessions` | volume با owner نامناسب | image فعلی entrypoint آن را اصلاح می‌کند |
| `relation ... does not exist` | database ساخته شده اما Odoo initialize نشده | یک‌بار `-i base` یا database creation صحیح اجرا کنید |
| addon در Apps دیده نمی‌شود | Apps list update نشده یا manifest invalid است | Update Apps List، بررسی manifest و addons_path |

## منابع

[1] [Odoo 19 — System configuration](https://www.odoo.com/documentation/19.0/administration/on_premise/deploy.html)
[2] [Odoo 19 — Source install](https://www.odoo.com/documentation/19.0/administration/on_premise/source.html)
[3] [pgvector — Official documentation and Docker images](https://github.com/pgvector/pgvector)
[4] [PostgreSQL — CREATE ROLE](https://www.postgresql.org/docs/current/sql-createrole.html)

## 12. بهینه‌سازی performance

Odoo در حالت پیش‌فرض با `workers=0` از server چندریسمانی استفاده می‌کند که برای development مناسب است. مستندات رسمی Odoo برای production، multiprocessing server را با مقدار non-zero برای `workers` توصیه می‌کند [1]. این پروژه مقدار را از environment می‌گیرد:

```env
ODOO_WORKERS=2
ODOO_MAX_CRON_THREADS=1
```

قاعدهٔ نظری Odoo برای سقف workerها `(CPU * 2) + 1` است و تقریباً هر worker سبک 150MB و worker سنگین 1GB RAM مصرف می‌کند [1]. این فقط نقطهٔ شروع است؛ برای PaaS کوچک، 2 worker معمولاً safer است و باید با metrics واقعی CPU/RAM، latency و تعداد connectionهای PostgreSQL تنظیم شود. افزایش workers بدون RAM کافی سرعت را کم و باعث OOM/restart می‌کند.

در deployment پشت reverse proxy، `proxy_mode=True` و `gevent_port=8072` لازم است. Odoo یک worker اختصاصی gevent برای live chat/websocket ایجاد می‌کند و proxy باید مسیرهای websocket را به آن port route کند [1]. پورت HTTP اصلی `8069` است.

تنظیمات memory/time به‌عنوان guardrail باقی می‌مانند:

```ini
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_time_cpu = 600
limit_time_real = 1200
limit_request = 8192
max_cron_threads = 1
```

این مقادیر را بر اساس memory limit واقعی PaaS تنظیم کنید. افزایش hard limit بدون افزایش RAM، optimization نیست. برای database خارجی، latency شبکه و `db_maxconn` نیز مهم‌اند؛ PostgreSQL managed باید ظرفیت connection متناسب با مجموع workerها و سرویس‌های دیگر داشته باشد.

بهینه‌سازی application باید با اندازه‌گیری انجام شود: queryهای N+1 را حذف کنید، روی فیلترها و relationهای پرتکرار index مناسب بسازید، عملیات ORM را batch کنید، cronهای سنگین را زمان‌بندی کنید و گزارش‌های بزرگ را صفحه‌بندی کنید. فعال‌کردن `log_sql`، debug asset یا log level بسیار verbose در production می‌تواند I/O را زیاد کند و فقط برای profiling موقت مناسب است.

## منابع performance

[1] [Odoo 19 — System configuration](https://www.odoo.com/documentation/19.0/administration/on_premise/deploy.html)
[2] [Odoo 19 — Command-line interface](https://www.odoo.com/documentation/19.0/developer/reference/cli.html)

## 13. استقرار از سورس تجاری Odoo

در این پروژه source کامل نسخهٔ `19.0+e.20260223` در مسیر `odoo-19.0+e.20260223/` نگهداری می‌شود. اجرای server با launcher رسمی `setup/odoo` انجام می‌شود و source با `PYTHONPATH` مستقیماً اجرا می‌گردد؛ بنابراین Dockerfile برای جلوگیری از ساخت wheel اضافی، source را دوباره به‌صورت package کپی نمی‌کند. این روش تمام فایل‌های source و Enterprise addons را حفظ می‌کند و image را کوچک‌تر و build را پایدارتر نگه می‌دارد.

فایل `odoo.conf` در root خود source قرار دارد. entrypoint از آن یک نسخهٔ runtime در `/tmp/odoo-runtime.conf` می‌سازد و secretهای PostgreSQL و Odoo را فقط در runtime تزریق می‌کند. مقدارهای زیر در config به‌صورت placeholder باقی می‌مانند:

```ini
admin_passwd = __ODOO_ADMIN_PASSWD__
db_host = __DB_HOST__
db_port = __DB_PORT__
db_user = __DB_USER__
db_password = __DB_PASSWORD__
addons_path = /opt/odoo/odoo-19.0+e.20260223/odoo/addons,/mnt/extra-addons
```

مسیر اول addons داخلی source تجاری و مسیر دوم external addons پروژه است. هفت custom addon پس از build در `/mnt/extra-addons` قرار می‌گیرند: `l10n_ir_fonts`, `persian_translation`, `payment_zarinpal`, `disable_enterprise`, `l10n_ir_account_reports`, `l10n_ir_account` و `l10n_ir_states`. dependencyهای `web_enterprise` و `account_reports` نیز از source Enterprise resolve می‌شوند. `parspack_auto_database_backup` عمداً در image قرار نگرفته است، چون به `auto_database_backup` وابستگی دارد که در source ارائه‌شده وجود ندارد.

## 14. initialization اولیهٔ Enterprise

برای database جدید، initialization را به‌صورت one-shot و قبل از اجرای server پایدار انجام دهید:

```bash
python /opt/odoo/odoo-19.0+e.20260223/setup/odoo \
  --config=/tmp/odoo-runtime.conf \
  -d <database_name> \
  -i base,l10n_ir_fonts,persian_translation,payment_zarinpal,disable_enterprise,l10n_ir_account_reports \
  --stop-after-init
```

گزینهٔ `--stop-after-init` طبق CLI رسمی Odoo پس از تکمیل عملیات server را متوقف می‌کند. سپس process عادی را با همان config اجرا کنید. این ترتیب از race condition روی database نیمه‌ساخته و خطای موقت نبودن `ir_module_module` جلوگیری می‌کند.

## 15. GitHub Actions و محرمانگی

workflow پروژه image را روی GHCR منتشر می‌کند و باید از `secrets.GITHUB_TOKEN` داخلی GitHub استفاده کند. token شخصی یا password registry نباید در YAML، Dockerfile، README یا Git commit شود. اگر tokenی در گفتگو، log یا repository نمایش داده شد، آن را revoke و credential جدید را از مسیر امن GitHub تنظیم کنید.

## منابع جدید

[3] [Odoo 19 — Building a Module](https://www.odoo.com/documentation/19.0/developer/tutorials/backend.html)
[4] [Odoo 19 — Command-line interface](https://www.odoo.com/documentation/19.0/developer/reference/cli.html)
