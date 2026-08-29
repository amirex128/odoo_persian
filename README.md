# Odoo 19 + OCA Web Addons

این مخزن یک image سفارشی **Odoo 19 Community** بر پایهٔ image رسمی `odoo:19.0` می‌سازد. تمام addonهای موجود در شاخهٔ `19.0` مخزن رسمی [OCA/web](https://github.com/OCA/web/tree/19.0) داخل `addons/` قرار گرفته‌اند و مسیر آن‌ها در `config/odoo.conf` به Odoo معرفی شده است.

> این image برای PaaSهایی طراحی شده است که از GitHub build می‌کنند و فقط به یک `Dockerfile` نیاز دارند. برای PaaS، PostgreSQL باید به‌صورت سرویس جداگانه ارائه شود؛ PostgreSQL را داخل image Odoo اجرا نکنید.

## ساختار پروژه

| مسیر | کاربرد |
|---|---|
| `Dockerfile` | ساخت image مستقل PaaS از `odoo:19.0` و نصب وابستگی `bokeh` |
| `entrypoint.sh` | جایگزینی secretهای runtime و سپس اجرای entrypoint رسمی Odoo |
| `config/odoo.conf` | تنظیم addons، data directory، پورت‌ها و محدودیت‌ها |
| `addons/` | addonهای OCA/web شاخهٔ `19.0` |
| `docker-compose.yml` | اجرای کامل محلی با PostgreSQL و mount زندهٔ addonها |
| `.env.compose.example` | env نمونه برای اجرای Docker Compose لوکال |
| `.env.paas.example` | env نمونه برای PaaS و PostgreSQL خارجی |
| `docs/odoo-configuration-and-operations.md` | راهنمای جامع تنظیمات، کانفیگ، امنیت، PostgreSQL/pgvector و عملیات Odoo |
| `docs/odoo-addon-development.md` | راهنمای جامع ساخت، توسعه، امنیت و تست addon |
| تنظیمات performance | workers، cron، gevent و limits در env و `config/odoo.conf` |

## راه‌اندازی روی PaaS با Dockerfile
برای ساخت role اختصاصی Odoo در PostgreSQL، با administrator وارد database `postgres` شوید:

```bash
psql -h <POSTGRES_HOST> -p <POSTGRES_PORT> -U <POSTGRES_ADMIN_USER> -d postgres
```

سپس role را بسازید:

```sql
CREATE ROLE odoo LOGIN PASSWORD '<POSTGRES_PASSWORD>' CREATEDB;
```

اگر role از قبل وجود دارد، password آن را هماهنگ کنید:

```sql
ALTER ROLE odoo WITH LOGIN PASSWORD '<POSTGRES_PASSWORD>';
```

برای نصب و فعال‌سازی pgvector در database هدف:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
SELECT extversion FROM pg_extension WHERE extname = 'vector';
```

راهنمای کامل این مراحل در [راهنمای تنظیمات و عملیات Odoo](docs/odoo-configuration-and-operations.md) آمده است.
در تنظیمات build سرویس، ریشهٔ این repository را به‌عنوان context انتخاب کنید و Dockerfile پیش‌فرض را استفاده کنید. فایل `.env.paas.example` فقط template است؛ مقادیر واقعی آن را در بخش Environment/Secrets سرویس PaaS ثبت کنید، زیرا Dockerfile به‌تنهایی فایل `.env` را از filesystem سرویس بارگذاری نمی‌کند. سرویس باید HTTP را روی پورت **8069** به بیرون publish کند؛ پورت **8072** برای gevent/live-bus در صورت پشتیبانی PaaS قابل publish است.

متغیرهای runtime زیر را در بخش Secrets/Environment سرویس ثبت کنید:

| متغیر | مقدار نمونه | توضیح |
|---|---|---|
| `POSTGRES_HOST` یا `HOST` | `postgres-service` | hostname یا آدرس سرور PostgreSQL خارجی |
| `POSTGRES_PORT` یا `PORT` | `5432` | پورت PostgreSQL خارجی |
| `POSTGRES_USER` یا `USER` | `odoo` | role واقعی PostgreSQL |
| `POSTGRES_PASSWORD` یا `PASSWORD` | secret | رمز همان role PostgreSQL؛ نه `ODOO_ADMIN_PASSWD` |
| `ODOO_ADMIN_PASSWD` | secret جداگانه | master password مدیریت database در Odoo |
| `ODOO_LIST_DB` | `False` در production | جلوگیری از نمایش database selector پس از تعیین dbfilter |

نام hostname پایگاه‌داده در سرویس شما باید در `HOST` قرار گیرد. image رسمی Odoo متغیرهای `HOST`، `PORT`، `USER` و `PASSWORD` را به‌صورت رسمی پشتیبانی می‌کند و قبل از شروع Odoo آماده‌بودن PostgreSQL را بررسی می‌کند.

### Volumeهای پیشنهادی PaaS

| Mount path | نوع | ضرورت | دلیل |
|---|---|---|---|
| `/var/lib/odoo` | Persistent volume | ضروری برای production | filestore، session و داده‌های runtime Odoo؛ entrypoint در startup مالکیت آن را به `odoo:odoo` اصلاح می‌کند |
| `/mnt/extra-addons` | معمولاً لازم نیست | اختیاری | addonها در image build کپی شده‌اند؛ فقط برای override یا addonهای خارج از Git استفاده شود |
| `/etc/odoo` | معمولاً لازم نیست | اختیاری | config در image وجود دارد؛ mount کردن کل این مسیر می‌تواند فایل config image را override کند |

در Compose، volume پایگاه‌داده روی `/var/lib/postgresql` mount می‌شود، نه `/var/lib/postgresql/data`؛ این الگوی لازم imageهای PostgreSQL 18+ برای data directory نسخه‌ای است. اگر PaaS دیسک را با `root:root` mount کند، image هنگام startup با دسترسی root پوشهٔ `/var/lib/odoo/sessions` را می‌سازد، مالکیت کل data directory را به `odoo:odoo` تغییر می‌دهد و سپس Odoo را با کاربر `odoo` اجرا می‌کند. بنابراین لازم نیست روی دیسک از قبل permission خاصی تنظیم کنید؛ فقط volume را روی همین مسیر mount کنید. پایگاه‌داده و filestore باید هر دو backup شوند. volume جایگزین backup نیست. اگر PaaS فقط یک volume اجازه می‌دهد، `/var/lib/odoo` را انتخاب کنید و PostgreSQL را به سرویس مدیریت‌شدهٔ جداگانه وصل کنید.

### خطای password authentication failed

این خطا یعنی DNS، آدرس و پورت درست هستند، اما password ارسال‌شده برای role PostgreSQL صحیح نیست. مقدار `ODOO_ADMIN_PASSWD` فقط master password داخلی Odoo است و نباید به‌عنوان رمز PostgreSQL استفاده شود. در PaaS، متغیرهای `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER` و `POSTGRES_PASSWORD` را دقیقاً از بخش connection/service PostgreSQL کپی کنید؛ entrypoint آن‌ها را به متغیرهای رسمی image Odoo نگاشت می‌کند. اگر database با یک volume قبلاً initialize شده باشد، تغییر `POSTGRES_PASSWORD` در Environment به‌تنهایی password role را عوض نمی‌کند؛ باید password role `odoo` را داخل PostgreSQL با `ALTER ROLE odoo PASSWORD '...'` تغییر دهید یا secret PaaS را با password فعلی database یکسان کنید. همچنین credentialهایی که قبلاً در محیط یا Git قرار گرفته‌اند باید فوراً rotate شوند.

## اجرای محلی

ابتدا فایل env را بسازید و secretهای آن را تغییر دهید:

```bash
cp .env.compose.example .env
```

سپس build و اجرا کنید:

```bash
docker compose build
docker compose up -d
```

Odoo در [http://localhost:8069](http://localhost:8069) در دسترس است. برای دیدن logها:

```bash
docker compose logs -f odoo
```

برای توقف:

```bash
docker compose down
```

برای حذف داده‌های محلی نیز باید volumeها را آگاهانه حذف کنید:

```bash
docker compose down -v
```

در Compose، image پیش‌فرض database برابر `pgvector/pgvector:0.8.6-pg18-trixie` است؛ این image از PostgreSQL 18 به‌همراه pgvector استفاده می‌کند. Registry رسمی pgvector در حال حاضر tag دقیق `18.1` منتشر نمی‌کند و tag `pg18` را روی minor version فعلی PostgreSQL 18 ارائه می‌دهد؛ بنابراین اگر PaaS شما الزام سخت برای PostgreSQL 18.1 دارد، باید image سفارشی جداگانه بر پایهٔ `postgres:18.1` ساخته شود. پوشهٔ `./addons` روی `/mnt/extra-addons` mount شده است؛ بنابراین تغییر یا افزودن یک addon در سیستم محلی، بدون rebuild image در container قابل مشاهده خواهد بود. برای فعال‌سازی addon در database، از Apps با حالت developer، گزینهٔ **Update Apps List** و سپس نصب addon استفاده کنید. صرفاً قرارگرفتن فایل addon روی filesystem به‌معنی نصب آن در database نیست.

## اجرای مستقیم image مانند PaaS

پس از build، اجرای مستقل بدون Compose را می‌توان با یک PostgreSQL خارجی انجام داد:

```bash
docker build -t odoo19-paas .
docker run --rm --name odoo19-paas \
  -p 8069:8069 \
  -e HOST=host.docker.internal \
  -e PORT=5432 \
  -e USER=odoo \
  -e PASSWORD='replace-me' \
  -e ODOO_ADMIN_PASSWD='replace-with-a-different-secret' \
  -e ODOO_LIST_DB=False \
  -v odoo19-paas-data:/var/lib/odoo \
  odoo19-paas
```

در Linux برای PostgreSQL روی host ممکن است به `--add-host=host.docker.internal:host-gateway` یا hostname شبکهٔ PaaS نیاز باشد. توصیهٔ production استفاده از PostgreSQL managed/private network است، نه PostgreSQL روی host توسعه‌دهنده.

## بررسی addonها

این build شامل ۳۲ addon از OCA/web شاخهٔ `19.0` است. برای بررسی manifestها در container:

```bash
docker compose exec odoo bash -lc \
  "find /mnt/extra-addons -mindepth 2 -maxdepth 2 -name __manifest__.py | wc -l"
```

یکی از addonهای قابل بررسی `web_responsive` است. یک addon تا زمانی که dependencyهای آن در database نصب نشده باشند نصب نمی‌شود. `web_widget_bokeh_chart` نیز طبق manifest خود به `bokeh==3.9.0` نیاز دارد و Dockerfile آن را نصب می‌کند.

برای پنج addon ایرانی، پس از deploy یا تغییر فایل‌ها باید در Odoo حالت developer را فعال کنید و از مسیر **Apps → Update Apps List → Update** فهرست را refresh کنید. فیلتر پیش‌فرض **Apps** فقط moduleهایی را نشان می‌دهد که در manifest آن‌ها `application=True` است؛ این flag برای addonهای کاربردی پروژه اضافه شده است. `l10n_ir_fonts`, `persian_translation`, `payment_zarinpal`, `disable_enterprise` و `l10n_ir_account_reports` اکنون در مسیر صحیح `/mnt/extra-addons` قرار دارند.

دو addon محدودیت dependency دارند: `disable_enterprise` به `web_enterprise` و `l10n_ir_account_reports` به `account_reports` نیاز دارند؛ هر دو در image رسمی Community موجود نیستند و در Community قابل نصب نخواهند بود. برای آن‌ها باید Odoo Enterprise با addonهای Enterprise متناظر استفاده شود. `l10n_ir_fonts`, `persian_translation` و `payment_zarinpal` در image Community تست و قابل نصب هستند. این نتیجه با تعریف رسمی `application`, `installable` و `depends` در manifest Odoo سازگار است.

## بهینه‌سازی performance

در production، Odoo با `ODOO_WORKERS=2` و `ODOO_MAX_CRON_THREADS=1` شروع می‌شود و از multiprocessing استفاده می‌کند. مقدار workers باید با CPU و RAM واقعی PaaS تنظیم شود؛ راهنمای رسمی Odoo برای تخمین نظری از `(CPU × 2) + 1` استفاده می‌کند، اما RAM و تعداد connectionهای PostgreSQL محدودکنندهٔ اصلی هستند. برای سرویس کوچک با 1 تا 2 vCPU و RAM محدود، 2 worker نقطهٔ شروع امن‌تری از افزایش بی‌رویه است. برای بار بالاتر، مقدار را مرحله‌ای افزایش دهید و CPU، RAM، latency و database connections را از metrics سرویس بررسی کنید.

`gevent_port=8072` برای live bus باقی می‌ماند و reverse proxy باید websocket/live requests را مطابق مستندات Odoo به آن route کند. `proxy_mode=True` فقط زمانی صحیح است که سرویس پشت reverse proxy/PaaS باشد. `limit_memory_*` و `limit_time_*` برای recycle کردن workerهای پرمصرف حفظ شده‌اند؛ افزایش آن‌ها بدون افزایش RAM می‌تواند باعث OOM شود.

تنظیمات performance در `.env.paas.example` و `.env.compose.example` قابل تغییر هستند:

```env
ODOO_WORKERS=2
ODOO_MAX_CRON_THREADS=1
```

افزایش سرعت فقط با workers حل نمی‌شود. queryهای سنگین addonها، نبود index، گزارش‌های بزرگ، تعداد زیاد cronها، latency PostgreSQL و assetهای frontend نیز باید با profiling و metrics بررسی شوند. از فعال‌کردن `log_sql` یا debug logging در production خودداری کنید، زیرا I/O و حجم log را بالا می‌برد.

## نکات production

در محیط عمومی، `ODOO_LIST_DB=False` را تنظیم کنید و یک `dbfilter` متناسب با domain خود در `odoo.conf` اضافه کنید. مقدار `admin_passwd` را هرگز در Git commit نکنید؛ wrapper مقدار آن را در runtime از `ODOO_ADMIN_PASSWD` می‌گیرد. TLS باید در reverse proxy یا خود PaaS terminate شود و `proxy_mode=True` برای این حالت فعال است.

## راهنماهای پروژه

| سند | موضوع |
|---|---|
| [راهنمای تنظیمات و عملیات Odoo](docs/odoo-configuration-and-operations.md) | نصب، env، PostgreSQL، pgvector، امنیت، volume، backup، reverse proxy و عیب‌یابی |
| [راهنمای ساخت Addon](docs/odoo-addon-development.md) | ساختار module، manifest، ORM، مدل، view، security، OWL، report، test و انتشار |

## منابع رسمی

[1] [Odoo 19 — Source install](https://www.odoo.com/documentation/19.0/administration/on_premise/source.html)
[2] [Odoo 19 — System configuration](https://www.odoo.com/documentation/19.0/administration/on_premise/deploy.html)
[3] [Odoo Official Image — Docker Hub](https://hub.docker.com/_/odoo)
[4] [Odoo official Docker repository — 19.0](https://github.com/odoo/docker/tree/master/19.0)
[5] [OCA/web — branch 19.0](https://github.com/OCA/web/tree/19.0)
[6] [pgvector official Docker image](https://hub.docker.com/r/pgvector/pgvector)