psql -U postgres -c "CREATE USER odoo128 WITH PASSWORD 'afFXQuCoAdUR5rdn9t5d' CREATEDB;"



مسیر داخل کانتینر,توضیح,اولویت,پیشنهاد اندازه اولیه
/var/lib/odoo,Filestore (فایل‌های آپلود شده، پیوست‌ها، تصاویر، کش و ...),بسیار ضروری,حداقل ۵–۱۰ گیگابایت
/mnt/extra-addons,ماژول‌های سفارشی شما (web_responsive و بقیه),ضروری,۱–۲ گیگابایت