import streamlit as st
import pandas as pd
from datetime import datetime
import time
import pytz
import gspread
from google.oauth2.service_account import Credentials

# إعداد الصفحة
st.set_page_config(
    page_title="نظام البصمة",
    page_icon="🔐",
    layout="centered",
    initial_sidebar_state="collapsed"
)

# إعداد CSS مخصص
st.markdown("""
<style>
    /* تنسيق الخط العربي */
    @import url('https://fonts.googleapis.com/css2?family=Tajawal:wght@300;400;500;700&display=swap');
    
    .rtl {
        direction: rtl;
        text-align: right;
        font-family: 'Tajawal', sans-serif;
    }
    
    /* تنسيق العنوان الرئيسي */
    .main-title {
        text-align: center;
        font-size: 3rem;
        font-weight: bold;
        color: #667eea;
        margin-bottom: 2rem;
        text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
    }
    
    /* تنسيق البطاقة الرئيسية */
    .fingerprint-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        border-radius: 20px;
        padding: 30px;
        margin-bottom: 30px;
        box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        color: white;
        text-align: center;
    }
    
    /* تنسيق دائرة البصمة */
    .fingerprint-circle {
        width: 150px;
        height: 150px;
        border-radius: 50%;
        background: linear-gradient(45deg, #4facfe, #00f2fe);
        display: flex;
        align-items: center;
        justify-content: center;
        margin: 0 auto 20px;
        cursor: pointer;
        transition: all 0.3s ease;
        box-shadow: 0 10px 30px rgba(79, 172, 254, 0.4);
    }
    
    .fingerprint-circle:hover {
        transform: scale(1.1);
        box-shadow: 0 15px 40px rgba(79, 172, 254, 0.6);
    }
    
    .fingerprint-icon {
        font-size: 4rem;
        color: white;
        text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
    }
    
    /* تنسيق أزرار الأشخاص */
    .user-buttons {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
        gap: 15px;
        margin-bottom: 30px;
    }
    
    /* تنسيق حالة النجاح */
    .success-message {
        background: linear-gradient(45deg, #56ab2f, #a8e6cf);
        color: #2d5016;
        padding: 15px;
        border-radius: 10px;
        text-align: center;
        font-weight: bold;
        margin: 20px 0;
    }
    
    /* تنسيق حالة الخطأ */
    .error-message {
        background: linear-gradient(45deg, #ff416c, #ff4b2b);
        color: white;
        padding: 15px;
        border-radius: 10px;
        text-align: center;
        font-weight: bold;
        margin: 20px 0;
    }
    
    /* تنسيق سجل الحضور */
    .attendance-log {
        background: rgba(255, 255, 255, 0.95);
        border-radius: 15px;
        padding: 20px;
        box-shadow: 0 5px 15px rgba(0,0,0,0.1);
    }
    
    .log-entry {
        padding: 12px;
        margin-bottom: 10px;
        background: linear-gradient(135deg, #f093fb, #f5576c);
        color: white;
        border-radius: 10px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        box-shadow: 0 3px 10px rgba(240, 147, 251, 0.3);
    }
    
    .log-entry.check-in {
        background: linear-gradient(135deg, #4facfe, #00f2fe);
    }
    
    .log-entry.check-out {
        background: linear-gradient(135deg, #ff9472, #f2709c);
    }
    
    /* إخفاء عناصر Streamlit غير المرغوبة */
    .stDeployButton {display:none;}
    footer {visibility: hidden;}
    .stApp > header {visibility: hidden;}
    
    /* تنسيق الأزرار */
    .stButton > button {
        width: 100%;
        border-radius: 12px;
        border: none;
        padding: 15px;
        font-size: 1.1rem;
        font-weight: bold;
        transition: all 0.3s ease;
    }
    
    /* تنسيق الجدول */
    .dataframe {
        direction: rtl;
        text-align: right;
    }
    
    /* تنسيق أزرار الدخول والخروج */
    .action-buttons {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 20px;
        margin: 20px 0;
    }
    
    .check-in-btn {
        background: linear-gradient(45deg, #4facfe, #00f2fe) !important;
        color: white !important;
        border: none !important;
        padding: 20px !important;
        border-radius: 15px !important;
        font-size: 1.2rem !important;
        font-weight: bold !important;
        transition: all 0.3s ease !important;
    }
    
    .check-out-btn {
        background: linear-gradient(45deg, #ff9472, #f2709c) !important;
        color: white !important;
        border: none !important;
        padding: 20px !important;
        border-radius: 15px !important;
        font-size: 1.2rem !important;
        font-weight: bold !important;
        transition: all 0.3s ease !important;
    }
</style>
""", unsafe_allow_html=True)

# إعداد Google Sheets
def init_google_sheets():
    """تهيئة الاتصال بـ Google Sheets"""
    try:
        # استخدام بيانات الاعتماد من Streamlit secrets
        if "connections" in st.secrets and "gsheets" in st.secrets["connections"]:
            # استخدام Service Account
            service_account_info = {
                "type": st.secrets["connections"]["gsheets"]["type"],
                "project_id": st.secrets["connections"]["gsheets"]["project_id"],
                "private_key_id": st.secrets["connections"]["gsheets"]["private_key_id"],
                "private_key": st.secrets["connections"]["gsheets"]["private_key"],
                "client_email": st.secrets["connections"]["gsheets"]["client_email"],
                "client_id": st.secrets["connections"]["gsheets"]["client_id"],
                "auth_uri": st.secrets["connections"]["gsheets"]["auth_uri"],
                "token_uri": st.secrets["connections"]["gsheets"]["token_uri"],
                "auth_provider_x509_cert_url": st.secrets["connections"]["gsheets"]["auth_provider_x509_cert_url"],
                "client_x509_cert_url": st.secrets["connections"]["gsheets"]["client_x509_cert_url"]
            }
            
            scope = ['https://spreadsheets.google.com/feeds',
                    'https://www.googleapis.com/auth/drive']
            
            creds = Credentials.from_service_account_info(service_account_info, scopes=scope)
            client = gspread.authorize(creds)
            
            # فتح الشيت
            spreadsheet_url = st.secrets["connections"]["gsheets"]["spreadsheet"]
            sheet_id = spreadsheet_url.split('/d/')[1].split('/')[0]
            spreadsheet = client.open_by_key(sheet_id)
            worksheet = spreadsheet.sheet1  # أو يمكنك تحديد اسم الشيت المطلوب
            
            return worksheet
        else:
            st.error("❌ بيانات الاعتماد لـ Google Sheets غير موجودة في secrets.toml")
            return None
            
    except Exception as e:
        st.error(f"❌ خطأ في الاتصال بـ Google Sheets: {str(e)}")
        return None

# إعداد التوقيت المحلي للإسكندرية
ALEXANDRIA_TZ = pytz.timezone('Africa/Cairo')

def get_local_time():
    """الحصول على التوقيت المحلي للإسكندرية"""
    utc_time = datetime.utcnow()
    utc_time = pytz.utc.localize(utc_time)
    local_time = utc_time.astimezone(ALEXANDRIA_TZ)
    return local_time

def add_to_google_sheet(worksheet, name, action, timestamp):
    """إضافة سجل جديد إلى Google Sheets"""
    try:
        now = get_local_time()
        row = [
            name,
            action,  # "دخول" أو "خروج"
            now.strftime("%Y-%m-%d"),
            now.strftime("%H:%M:%S"),
            now.strftime("%I:%M:%S %p"),
            timestamp
        ]
        worksheet.append_row(row)
        return True
    except Exception as e:
        st.error(f"❌ خطأ في إضافة البيانات: {str(e)}")
        return False

def get_data_from_google_sheet(worksheet):
    """جلب البيانات من Google Sheets"""
    try:
        data = worksheet.get_all_records()
        return data
    except Exception as e:
        st.error(f"❌ خطأ في جلب البيانات: {str(e)}")
        return []

def setup_google_sheet_headers(worksheet):
    """إعداد عناوين الأعمدة في Google Sheets"""
    try:
        # التحقق من وجود العناوين
        if worksheet.row_count == 0 or not worksheet.row_values(1):
            headers = ['الاسم', 'النوع', 'التاريخ', 'الوقت_24', 'الوقت_12', 'الطابع_الزمني']
            worksheet.insert_row(headers, 1)
            return True
    except Exception as e:
        st.warning(f"تنبيه: {str(e)}")
        return False

# تهيئة البيانات في الجلسة
if 'selected_user' not in st.session_state:
    st.session_state.selected_user = None

if 'scanning' not in st.session_state:
    st.session_state.scanning = False

if 'last_action' not in st.session_state:
    st.session_state.last_action = {}

# تهيئة Google Sheets
worksheet = init_google_sheets()

if worksheet:
    setup_google_sheet_headers(worksheet)

# العنوان الرئيسي
st.markdown('<div class="rtl main-title">🔐 نظام البصمة</div>', unsafe_allow_html=True)

# قائمة الأشخاص
users = ["Amr", "Rana", "Farida Ahmed", "Hadel", "Fatma", "Farida Muhammed"]

# اختيار الشخص
st.markdown('<div class="rtl"><h3>اختر الشخص:</h3></div>', unsafe_allow_html=True)
cols = st.columns(len(users))

for i, user in enumerate(users):
    with cols[i]:
        if st.button(user, key=f"user_{user}"):
            st.session_state.selected_user = user
            st.success(f"تم اختيار: {user}")
            st.rerun()

# عرض الشخص المختار
if st.session_state.selected_user:
    st.markdown(f'<div class="rtl success-message">الشخص المختار: {st.session_state.selected_user}</div>', 
                unsafe_allow_html=True)
    
    # عرض آخر عملية للمستخدم المختار
    if worksheet:
        try:
            data = get_data_from_google_sheet(worksheet)
            user_records = [record for record in data if record.get('الاسم') == st.session_state.selected_user]
            if user_records:
                last_record = user_records[-1]
                last_action = last_record.get('النوع', '')
                last_time = last_record.get('الوقت_12', '')
                
                if last_action == 'دخول':
                    st.info(f"📍 آخر عملية: دخول في {last_time}")
                    recommended_action = "خروج"
                else:
                    st.info(f"📍 آخر عملية: خروج في {last_time}")
                    recommended_action = "دخول"
                
                st.session_state.last_action[st.session_state.selected_user] = last_action
            else:
                recommended_action = "دخول"
        except:
            recommended_action = "دخول"

# قسم البصمة
st.markdown('<div class="rtl"><h3>📱 تسجيل الحضور:</h3></div>', unsafe_allow_html=True)

if st.session_state.selected_user:
    # أزرار الدخول والخروج
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("🟢 تسجيل دخول", key="check_in", help="تسجيل دخول إلى العمل"):
            if worksheet:
                st.session_state.scanning = True
                with st.spinner("🔍 جاري تسجيل الدخول..."):
                    time.sleep(2)
                
                now = get_local_time()
                success = add_to_google_sheet(
                    worksheet, 
                    st.session_state.selected_user, 
                    "دخول", 
                    now.timestamp()
                )
                
                if success:
                    st.success(f"✅ تم تسجيل دخول: {st.session_state.selected_user}")
                    st.balloons()
                else:
                    st.error("❌ فشل في تسجيل الدخول")
                
                st.session_state.selected_user = None
                st.session_state.scanning = False
                st.rerun()
    
    with col2:
        if st.button("🔴 تسجيل خروج", key="check_out", help="تسجيل خروج من العمل"):
            if worksheet:
                st.session_state.scanning = True
                with st.spinner("🔍 جاري تسجيل الخروج..."):
                    time.sleep(2)
                
                now = get_local_time()
                success = add_to_google_sheet(
                    worksheet, 
                    st.session_state.selected_user, 
                    "خروج", 
                    now.timestamp()
                )
                
                if success:
                    st.success(f"✅ تم تسجيل خروج: {st.session_state.selected_user}")
                else:
                    st.error("❌ فشل في تسجيل الخروج")
                
                st.session_state.selected_user = None
                st.session_state.scanning = False
                st.rerun()
else:
    st.warning("⚠️ من فضلك اختر الشخص أولاً")

# سجل الحضور
st.markdown('<div class="rtl"><h3>📋 سجل الحضور:</h3></div>', unsafe_allow_html=True)

if worksheet:
    try:
        attendance_data = get_data_from_google_sheet(worksheet)
        
        if attendance_data:
            # عرض آخر 10 سجلات
            recent_logs = attendance_data[-10:] if len(attendance_data) > 10 else attendance_data
            recent_logs.reverse()  # عرض الأحدث أولاً
            
            for entry in recent_logs:
                name = entry.get('الاسم', 'غير محدد')
                action = entry.get('النوع', 'غير محدد')
                date = entry.get('التاريخ', 'غير محدد')
                time_12 = entry.get('الوقت_12', entry.get('الوقت_24', 'غير محدد'))
                
                action_class = "check-in" if action == "دخول" else "check-out"
                action_icon = "🟢" if action == "دخول" else "🔴"
                
                st.markdown(f"""
                <div class="rtl log-entry {action_class}">
                    <div style="font-weight: bold; font-size: 1.1rem;">{action_icon} {name} - {action}</div>
                    <div style="opacity: 0.9;">{date} - {time_12}</div>
                </div>
                """, unsafe_allow_html=True)
            
            # إحصائيات سريعة
            st.markdown("### 📊 الإحصائيات:")
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("إجمالي السجلات", len(attendance_data))
            
            with col2:
                today = get_local_time().strftime("%Y-%m-%d")
                today_count = len([entry for entry in attendance_data if entry.get('التاريخ') == today])
                st.metric("سجلات اليوم", today_count)
            
            with col3:
                unique_users = len(set(entry.get('الاسم', '') for entry in attendance_data if entry.get('الاسم')))
                st.metric("الأشخاص", unique_users)
            
            with col4:
                check_ins_today = len([entry for entry in attendance_data 
                                     if entry.get('التاريخ') == today and entry.get('النوع') == 'دخول'])
                st.metric("دخول اليوم", check_ins_today)
            
            # عرض الجدول التفصيلي
            if st.checkbox("عرض الجدول التفصيلي"):
                df = pd.DataFrame(attendance_data)
                if not df.empty:
                    # ترتيب الأعمدة
                    cols_order = ['الاسم', 'النوع', 'التاريخ', 'الوقت_12']
                    available_cols = [col for col in cols_order if col in df.columns]
                    df_display = df[available_cols].copy()
                    st.dataframe(df_display, use_container_width=True)
            
            # رابط Google Sheets
            if "connections" in st.secrets and "gsheets" in st.secrets["connections"]:
                sheet_url = st.secrets["connections"]["gsheets"]["spreadsheet"]
                st.markdown(f"### 🔗 [فتح Google Sheet]({sheet_url})")
        
        else:
            st.info("📝 لا توجد سجلات حضور بعد")
    
    except Exception as e:
        st.error(f"❌ خطأ في عرض البيانات: {str(e)}")

else:
    st.error("❌ لا يمكن الاتصال بـ Google Sheets. تأكد من إعداد بيانات الاعتماد.")

# معلومات إضافية في الشريط الجانبي
with st.sidebar:
    st.markdown("### ℹ️ معلومات النظام")
    st.info("""
    **نظام البصمة الذكي**
    
    ✅ تسجيل دخول وخروج
    
    ✅ حفظ في Google Sheets
    
    ✅ إحصائيات فورية
    
    ✅ واجهة عربية جميلة
    
    ✅ متابعة لحظية
    
    🕐 التوقيت: الإسكندرية
    """)
    
    # عرض التوقيت الحالي
    current_time = get_local_time()
    st.markdown(f"**التوقيت الحالي (الإسكندرية):**")
    st.markdown(f"📅 {current_time.strftime('%d/%m/%Y')}")
    st.markdown(f"🕐 {current_time.strftime('%I:%M:%S %p')}")
    st.markdown(f"🌍 المنطقة الزمنية: {current_time.tzinfo}")
    
    # إضافة زر تحديث
    if st.button("🔄 تحديث البيانات"):
        st.cache_data.clear()
        st.rerun()
    
    # معلومات الإعداد
    st.markdown("### ⚙️ إعداد Google Sheets")
    if worksheet:
        st.success("✅ متصل بـ Google Sheets")
    else:
        st.error("❌ غير متصل بـ Google Sheets")
        st.markdown("""
        **لإعداد الاتصال:**
        1. أنشئ Service Account في Google Cloud
        2. أضف البيانات إلى secrets.toml
        3. شارك الشيت مع Service Account
        """)

# رسالة ترحيب للمستخدمين الجدد
if worksheet and 'welcome_shown' not in st.session_state:
    try:
        data = get_data_from_google_sheet(worksheet)
        if not data:
            st.balloons()
            st.success("🎉 مرحباً بك في نظام البصمة المحدث!")
    except:
        pass
    st.session_state.welcome_shown = True
