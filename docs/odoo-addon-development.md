# راهنمای جامع ساخت Addon در Odoo 19

این سند مسیر ساخت، نصب، توسعه، تست و انتشار addon برای Odoo 19 را توضیح می‌دهد. ساختار و مفاهیم بر اساس Server framework 101 و راهنماهای رسمی Odoo 19 است [1].

## 1. Addon چیست؟

در Odoo، یک module یا addon مجموعه‌ای از Python code، مدل‌ها، viewها، security rules، داده‌های XML/CSV، assetهای JavaScript/SCSS و ترجمه‌هاست که به‌صورت اختیاری روی database نصب می‌شود. فقط کپی‌شدن addon در `addons_path` آن را نصب نمی‌کند؛ باید Apps List به‌روزرسانی و module نصب شود.

## 2. ساختار پیشنهادی

```text
my_module/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   └── my_model.py
├── views/
│   └── my_model_views.xml
├── security/
│   ├── ir.model.access.csv
│   └── security.xml
├── data/
│   └── data.xml
├── demo/
│   └── demo.xml
├── controllers/
│   ├── __init__.py
│   └── main.py
├── static/
│   └── src/
│       ├── js/
│       ├── xml/
│       └── scss/
├── report/
├── wizard/
├── i18n/
└── tests/
    ├── __init__.py
    └── test_my_model.py
```

فایل‌های `__init__.py` باید packageهای Python را import کنند:

```python
# my_module/__init__.py
from . import models
from . import controllers
```

```python
# my_module/models/__init__.py
from . import my_model
```

## 3. Manifest

`__manifest__.py` metadata و dependencyهای addon را تعریف می‌کند:

```python
{
    "name": "My Module",
    "version": "19.0.1.0.0",
    "category": "Tools",
    "summary": "A concise description",
    "description": "Longer module description.",
    "author": "Your Company",
    "license": "LGPL-3",
    "depends": ["base"],
    "data": [
        "security/ir.model.access.csv",
        "views/my_model_views.xml",
    ],
    "demo": [
        "demo/demo.xml",
    ],
    "assets": {
        "web.assets_backend": [
            "my_module/static/src/js/my_widget.js",
            "my_module/static/src/scss/my_module.scss",
        ],
    },
    "installable": True,
    "application": True,
}
```

`depends` باید همهٔ addonهایی را شامل شود که مدل، view، asset یا سرویس آن‌ها استفاده می‌شود. ترتیب فایل‌های `data` مهم است؛ security معمولاً قبل از view و action قرار می‌گیرد. از `auto_install` فقط زمانی استفاده کنید که منطق نصب خودکار آن روشن باشد.

## 4. مدل و fieldها

مدل‌ها با `_name` تعریف می‌شوند و از ORM استفاده می‌کنند:

```python
from odoo import api, fields, models
from odoo.exceptions import ValidationError


class MyModel(models.Model):
    _name = "my.model"
    _description = "My Model"
    _order = "sequence, id"

    name = fields.Char(required=True, index=True)
    sequence = fields.Integer(default=10)
    active = fields.Boolean(default=True)
    description = fields.Text()
    amount = fields.Float()
    state = fields.Selection(
        [("draft", "Draft"), ("done", "Done")],
        default="draft",
        required=True,
    )
    partner_id = fields.Many2one("res.partner", ondelete="restrict")
    tag_ids = fields.Many2many("my.tag", string="Tags")
    line_ids = fields.One2many("my.line", "parent_id")
```

Fieldهای رابطه‌ای باید `ondelete` مناسب داشته باشند. `Many2one` رابطهٔ چندبه‌یک، `One2many` رابطهٔ معکوس و `Many2many` رابطهٔ چندبه‌چند است. برای داده‌های محاسباتی، dependency را دقیق اعلام کنید:

```python
subtotal = fields.Float(compute="_compute_subtotal", store=True)

@api.depends("quantity", "unit_price")
def _compute_subtotal(self):
    for record in self:
        record.subtotal = record.quantity * record.unit_price
```

## 5. ORM و متدها

از ORM به‌جای SQL مستقیم استفاده کنید:

```python
records = self.env["my.model"].search(
    [("active", "=", True)],
    order="sequence, id",
    limit=20,
)
record = self.env["my.model"].create({"name": "Example"})
record.write({"state": "done"})
record.unlink()
```

به recordsetها به‌صورت مجموعه نگاه کنید و از loopهای غیرضروری و query داخل loop اجتناب کنید. در صورت نیاز از `read_group`، prefetch و batch create/write استفاده کنید. SQL مستقیم فقط با دلیل روشن، پارامترهای امن و درک transaction انجام شود.

## 6. Constraint و validation

برای validation سطح Python از constraint استفاده کنید:

```python
from odoo import api, models
from odoo.exceptions import ValidationError


@api.constrains("amount")
def _check_amount(self):
    for record in self:
        if record.amount < 0:
            raise ValidationError("Amount cannot be negative.")
```

برای uniqueness ساده، SQL constraint معمولاً مناسب‌تر است:

```python
_sql_constraints = [
    (
        "my_model_name_unique",
        "unique(name)",
        "The name must be unique.",
    ),
]
```

## 7. View، action و menu

یک view پایه می‌تواند چنین باشد:

```xml
<odoo>
    <record id="view_my_model_list" model="ir.ui.view">
        <field name="name">my.model.list</field>
        <field name="model">my.model</field>
        <field name="arch" type="xml">
            <list>
                <field name="sequence" widget="handle"/>
                <field name="name"/>
                <field name="partner_id"/>
                <field name="state"/>
                <field name="active"/>
            </list>
        </field>
    </record>

    <record id="view_my_model_form" model="ir.ui.view">
        <field name="name">my.model.form</field>
        <field name="model">my.model</field>
        <field name="arch" type="xml">
            <form>
                <header>
                    <button name="action_done" type="object" string="Done"
                            class="btn-primary" invisible="state != 'draft'"/>
                    <field name="state" widget="statusbar"/>
                </header>
                <sheet>
                    <group>
                        <field name="name"/>
                        <field name="partner_id"/>
                        <field name="amount"/>
                    </group>
                </sheet>
            </form>
        </field>
    </record>

    <record id="action_my_model" model="ir.actions.act_window">
        <field name="name">My Records</field>
        <field name="res_model">my.model</field>
        <field name="view_mode">list,form</field>
    </record>

    <menuitem id="menu_my_root" name="My App" sequence="10"/>
    <menuitem id="menu_my_model" name="Records" parent="menu_my_root"
              action="action_my_model" sequence="10"/>
</odoo>
```

از XML IDهای یکتا با prefix نام addon استفاده کنید. در Odoo 19، syntax و viewهای نسخهٔ هدف را از مستندات همان نسخه بررسی کنید و viewهای قدیمی نسخه‌های قبلی را بدون بررسی کپی نکنید.

## 8. Security: گروه، access و record rule

داشتن menu یا view به‌معنی داشتن دسترسی نیست. برای هر مدل باید `ir.model.access.csv` بنویسید:

```csv
id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink
access_my_model_user,my.model user,model_my_model,base.group_user,1,1,1,0
```

برای محدودکردن رکوردها از record rule استفاده کنید:

```xml
<odoo>
    <record id="rule_my_model_own_records" model="ir.rule">
        <field name="name">My model: own records</field>
        <field name="model_id" ref="model_my_model"/>
        <field name="domain_force">[("create_uid", "=", user.id)]</field>
        <field name="groups" eval="[(4, ref("base.group_user"))]"/>
    </record>
</odoo>
```

قبل از انتشار، دسترسی کاربر عادی، manager و portal را جداگانه تست کنید. از `sudo()` فقط برای بخش محدود و مستدل استفاده کنید، زیرا record rules و access rights را دور می‌زند. راهنمای رسمی Odoo برای کنترل دسترسی و data security مرجع اصلی این بخش است [2].

## 9. Inheritance و توسعهٔ addonهای موجود

برای افزودن field یا behavior به مدل موجود از class inheritance استفاده کنید:

```python
from odoo import fields, models


class ResPartner(models.Model):
    _inherit = "res.partner"

    customer_code = fields.Char(index=True)
```

برای تغییر view از XML inheritance استفاده کنید:

```xml
<record id="view_partner_form_inherit_my_module" model="ir.ui.view">
    <field name="name">res.partner.form.inherit.my.module</field>
    <field name="model">res.partner</field>
    <field name="inherit_id" ref="base.view_partner_form"/>
    <field name="arch" type="xml">
        <xpath expr="//field[@name='vat']" position="after">
            <field name="customer_code"/>
        </xpath>
    </field>
</record>
```

تا حد امکان extension point، method super و xpath پایدار استفاده کنید و از جایگزین‌کردن کامل viewهای core پرهیز کنید.

## 10. Wizard و action method

Wizard معمولاً با `TransientModel` ساخته می‌شود:

```python
from odoo import fields, models


class MyWizard(models.TransientModel):
    _name = "my.wizard"
    _description = "My Wizard"

    note = fields.Text(required=True)

    def action_apply(self):
        active_ids = self.env.context.get("active_ids", [])
        records = self.env["my.model"].browse(active_ids).exists()
        records.write({"description": self.note})
        return {"type": "ir.actions.act_window_close"}
```

هر action عمومی باید context، access و امکان نبودن رکورد را در نظر بگیرد. دادهٔ کاربر را validate و در خروجی HTML/XML escape کنید.

## 11. Controller و API

Controller برای routeهای HTTP است:

```python
from odoo import http
from odoo.http import request


class MyController(http.Controller):
    @http.route("/my_module/health", type="http", auth="public", methods=["GET"])
    def health(self):
        return request.make_json_response({"status": "ok"})
```

برای دادهٔ حساس از `auth="user"`، CSRF protection و validation استفاده کنید. از public route برای عملیات write استفاده نکنید مگر با طراحی امنیتی کامل.

## 12. JavaScript، OWL و assets

فایل‌های frontend باید در `assets` manifest ثبت شوند. برای componentهای OWL از الگوی رسمی web framework استفاده کنید و template XML را در asset bundle مناسب قرار دهید. پس از تغییر assetها، در development با `--dev=assets` یا build مناسب مرورگر cache را بررسی کنید. JS را با APIهای رسمی نسخهٔ 19 بنویسید و از private internals وابسته به نسخه پرهیز کنید [3].

## 13. Report و QWeb

برای report، action گزارش، template QWeb و paper format مناسب تعریف کنید. داده‌هایی که در template چاپ می‌شوند باید از طریق record و context فراهم شوند. report را با دادهٔ فارسی، RTL، طول متن زیاد و permissionهای مختلف تست کنید.

## 14. ترجمه

رشته‌های user-facing را با `_()` در Python و سازوکار ترجمهٔ XML مشخص کنید. فایل‌های ترجمه در `i18n/` نگهداری می‌شوند و پس از تغییر field/view باید export یا update شوند. ترجمه را به‌جای hard-code کردن متن‌های قابل مشاهده استفاده کنید.

## 15. تست

ساختار تست:

```python
from odoo.tests.common import TransactionCase


class TestMyModel(TransactionCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.Model = cls.env["my.model"]

    def test_create_record(self):
        record = self.Model.create({"name": "Test"})
        self.assertEqual(record.name, "Test")
```

اجرای تست برای database مشخص:

```bash
odoo --config=/etc/odoo/odoo.conf \
  -d test_db -i my_module \
  --test-enable --stop-after-init
```

حداقل این موارد را تست کنید: installation و upgrade، access rights، record rules، create/write/unlink، constraintها، viewها، cronها، reportها و uninstall در صورت پشتیبانی. تست باید deterministic باشد و به سرویس بیرونی واقعی وابسته نباشد.

## 16. نصب، upgrade و توسعه در این repository

برای افزودن addon جدید، directory آن را زیر `addons/` قرار دهید، manifest و dependencyها را کامل کنید و image را rebuild کنید. در Odoo:

```bash
docker compose exec odoo odoo \
  --config=/tmp/odoo-runtime.conf \
  -d <ODOO_DATABASE> \
  -u my_module \
  --stop-after-init
```

در محیط PaaS، معمولاً redeploy image و سپس upgrade module از Apps یا command اجرایی سرویس انجام می‌شود. قبل از upgrade production backup database و filestore بگیرید.

## 17. checklist انتشار

| حوزه | پرسش کنترل |
|---|---|
| Manifest | version، license، depends و data صحیح‌اند؟ |
| Security | access CSV و record rules با نقش‌های واقعی تست شده‌اند؟ |
| ORM | query داخل loop، sudo بی‌دلیل و SQL ناامن وجود ندارد؟ |
| UI | list/form/search، mobile، RTL و translation بررسی شده‌اند؟ |
| Upgrade | module روی database قبلی upgrade می‌شود؟ |
| Tests | تست‌های مثبت، منفی و permission اجرا شده‌اند؟ |
| Performance | index، batch operation و asset bundle بررسی شده‌اند؟ |
| Deployment | addon در image و `addons_path` قابل مشاهده است؟ |

## منابع رسمی

[1] [Odoo 19 — Server framework 101](https://www.odoo.com/documentation/19.0/developer/tutorials/server_framework_101.html)
[2] [Odoo 19 — Restrict access to data](https://www.odoo.com/documentation/19.0/developer/howtos/rdtraining/04_securityintro.html)
[3] [Odoo 19 — Discover the web framework](https://www.odoo.com/documentation/19.0/developer/tutorials/discover_js_framework.html)
[4] [Odoo 19 — Define module data](https://www.odoo.com/documentation/19.0/developer/reference/backend/data.html)
[5] [Odoo 19 — Unit tests](https://www.odoo.com/documentation/19.0/developer/reference/backend/testing.html)
