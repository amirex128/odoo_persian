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
| `.env.example` | نمونهٔ متغیرهای محیطی؛ فایل واقعی `.env` commit نمی‌شود |

## راه‌اندازی روی PaaS با Dockerfile

در تنظیمات build سرویس، ریشهٔ این repository را به‌عنوان context انتخاب کنید و Dockerfile پیش‌فرض را استفاده کنید. سرویس باید HTTP را روی پورت **8069** به بیرون publish کند؛ پورت **8072** برای gevent/live-bus در صورت پشتیبانی PaaS قابل publish است.

متغیرهای runtime زیر را در بخش Secrets/Environment سرویس ثبت کنید:

| متغیر | مقدار نمونه | توضیح |
|---|---|---|
| `HOST` | `postgres-service` | hostname داخلی PostgreSQL |
| `PORT` | `5432` | پورت PostgreSQL |
| `USER` | `odoo` | role PostgreSQL |
| `PASSWORD` | secret | رمز role PostgreSQL |
| `ODOO_ADMIN_PASSWD` | secret جداگانه | master password مدیریت database در Odoo |
| `ODOO_LIST_DB` | `False` در production | جلوگیری از نمایش database selector پس از تعیین dbfilter |

نام hostname پایگاه‌داده در سرویس شما باید در `HOST` قرار گیرد. image رسمی Odoo متغیرهای `HOST`، `PORT`، `USER` و `PASSWORD` را به‌صورت رسمی پشتیبانی می‌کند و قبل از شروع Odoo آماده‌بودن PostgreSQL را بررسی می‌کند.

### Volumeهای پیشنهادی PaaS

| Mount path | نوع | ضرورت | دلیل |
|---|---|---|---|
| `/var/lib/odoo` | Persistent volume | ضروری برای production | filestore، session و داده‌های runtime Odoo |
| `/mnt/extra-addons` | معمولاً لازم نیست | اختیاری | addonها در image build کپی شده‌اند؛ فقط برای override یا addonهای خارج از Git استفاده شود |
| `/etc/odoo` | معمولاً لازم نیست | اختیاری | config در image وجود دارد؛ mount کردن کل این مسیر می‌تواند فایل config image را override کند |

پایگاه‌داده و filestore باید هر دو backup شوند. volume جایگزین backup نیست. اگر PaaS فقط یک volume اجازه می‌دهد، `/var/lib/odoo` را انتخاب کنید و PostgreSQL را به سرویس مدیریت‌شدهٔ جداگانه وصل کنید.

## اجرای محلی

ابتدا فایل env را بسازید و secretهای آن را تغییر دهید:

```bash
cp .env.example .env
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

در compose، پوشهٔ `./addons` روی `/mnt/extra-addons` mount شده است؛ بنابراین تغییر یا افزودن یک addon در سیستم محلی، بدون rebuild image در container قابل مشاهده خواهد بود. برای فعال‌سازی addon در database، از Apps با حالت developer، گزینهٔ **Update Apps List** و سپس نصب addon استفاده کنید. صرفاً قرارگرفتن فایل addon روی filesystem به‌معنی نصب آن در database نیست.

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

## نکات production

در محیط عمومی، `ODOO_LIST_DB=False` را تنظیم کنید و یک `dbfilter` متناسب با domain خود در `odoo.conf` اضافه کنید. مقدار `admin_passwd` را هرگز در Git commit نکنید؛ wrapper مقدار آن را در runtime از `ODOO_ADMIN_PASSWD` می‌گیرد. TLS باید در reverse proxy یا خود PaaS terminate شود و `proxy_mode=True` برای این حالت فعال است.

## منابع رسمی

[1] [Odoo 19 — Source install](https://www.odoo.com/documentation/19.0/administration/on_premise/source.html)
[2] [Odoo 19 — System configuration](https://www.odoo.com/documentation/19.0/administration/on_premise/deploy.html)
[3] [Odoo Official Image — Docker Hub](https://hub.docker.com/_/odoo)
[4] [Odoo official Docker repository — 19.0](https://github.com/odoo/docker/tree/master/19.0)
[5] [OCA/web — branch 19.0](https://github.com/OCA/web/tree/19.0)