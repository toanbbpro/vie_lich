package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/go-toast/toast"
	"golang.org/x/sys/windows/registry"
)

const (
	appName    = "VIE Lịch"
	aumid      = "com.toanbb.vieLich"
	regRunKey  = `Software\Microsoft\Windows\CurrentVersion\Run`
	regRunName = "VIE_Lich_Helper"
)

// ============================================================
// DATA MODELS
// ============================================================

type Event struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Body   string `json:"body"`
	FireAt string `json:"fireAt"` // RFC3339
}

type Schedule struct {
	Version     int     `json:"version"`
	GeneratedAt string  `json:"generatedAt"`
	ExpiresAt   string  `json:"expiresAt"`
	Timezone    string  `json:"timezone"`
	Events      []Event `json:"events"`
}

type FiredState struct {
	Version  int      `json:"version"`
	FiredIDs []string `json:"firedIds"`
}

// ============================================================
// PATHS
// ============================================================

func getAppDir() string {
	appdata := os.Getenv("APPDATA")
	return filepath.Join(appdata, "vie_lich")
}

func getSchedulePath() string {
	return filepath.Join(getAppDir(), "schedule.json")
}

func getFiredPath() string {
	return filepath.Join(getAppDir(), "fired.json")
}

// ============================================================
// READ / WRITE
// ============================================================

// Đọc schedule với retry — tránh race với Flutter đang ghi
func readSchedule() (*Schedule, error) {
	var lastErr error
	for i := 0; i < 3; i++ {
		data, err := os.ReadFile(getSchedulePath())
		if err != nil {
			lastErr = err
			time.Sleep(200 * time.Millisecond)
			continue
		}
		if len(data) >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
			data = data[3:]
		}
		var s Schedule
		if err := json.Unmarshal(data, &s); err != nil {
			lastErr = err
			time.Sleep(200 * time.Millisecond)
			continue
		}
		return &s, nil
	}
	return nil, lastErr
}

func readFired() *FiredState {
	data, err := os.ReadFile(getFiredPath())
	if err != nil {
		return &FiredState{Version: 1, FiredIDs: []string{}}
	}
	if len(data) >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
		data = data[3:]
	}

	var f FiredState
	if err := json.Unmarshal(data, &f); err != nil {
		return &FiredState{Version: 1, FiredIDs: []string{}}
	}
	return &f
}

// Atomic write: ghi tmp rồi rename
func writeFired(f *FiredState) error {
	path := getFiredPath()
	tmp := path + ".tmp"
	data, err := json.MarshalIndent(f, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(tmp, data, 0644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// ============================================================
// HELPERS
// ============================================================

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func sendToast(title, body string) error {
	n := toast.Notification{
		AppID:   aumid,
		Title:   title,
		Message: body,
	}
	return n.Push()
}

// ============================================================
// AUMID REGISTRATION
// ============================================================

// Đăng ký AUMID để Windows Toast chấp nhận — chỉ cần 1 lần
func registerAUMID() error {
	key, _, err := registry.CreateKey(
		registry.CURRENT_USER,
		`Software\Classes\AppUserModelId\`+aumid,
		registry.WRITE,
	)
	if err != nil {
		return err
	}
	defer key.Close()

	if err := key.SetStringValue("DisplayName", appName); err != nil {
		return err
	}
	// IconUri có thể để trống — Windows sẽ dùng icon mặc định
	return nil
}

// ============================================================
// AUTO STARTUP
// ============================================================

// Đăng ký helper vào HKCU\Run — không cần admin, chạy khi user login
func registerAutoStart() error {
	exePath, err := os.Executable()
	if err != nil {
		return err
	}

	key, _, err := registry.CreateKey(
		registry.CURRENT_USER,
		regRunKey,
		registry.WRITE,
	)
	if err != nil {
		return err
	}
	defer key.Close()

	// Quote path để handle space trong đường dẫn
	return key.SetStringValue(regRunName, fmt.Sprintf(`"%s"`, exePath))
}

// ============================================================
// SCHEDULE LOGIC
// ============================================================

// Tìm event sắp tới gần nhất chưa fire
func findNextEvent(s *Schedule, f *FiredState) (time.Time, *Event) {
	var next time.Time
	var nextEvt *Event
	now := time.Now()

	for i := range s.Events {
		e := &s.Events[i]
		if contains(f.FiredIDs, e.ID) {
			continue
		}
		t, err := time.Parse(time.RFC3339, e.FireAt)
		if err != nil {
			continue
		}
		if t.After(now) {
			if next.IsZero() || t.Before(next) {
				next = t
				nextEvt = e
			}
		}
	}
	return next, nextEvt
}

// Fire tất cả event đã đến giờ, ghi vào fired.json
func processDue(s *Schedule, f *FiredState) {
	now := time.Now()
	changed := false

	for i := range s.Events {
		e := &s.Events[i]
		if contains(f.FiredIDs, e.ID) {
			continue
		}
		t, err := time.Parse(time.RFC3339, e.FireAt)
		if err != nil {
			continue
		}
		if !t.After(now) {
			// Đã đến giờ → fire
			if err := sendToast(e.Title, e.Body); err != nil {
				fmt.Fprintf(os.Stderr, "Toast lỗi: %v\n", err)
				// Vẫn đánh dấu đã fire để không spam lại
			}
			f.FiredIDs = append(f.FiredIDs, e.ID)
			changed = true
			fmt.Printf("🔥 Đã fire: %s (%s)\n", e.Title, e.FireAt)
		}
	}

	if changed {
		if err := writeFired(f); err != nil {
			fmt.Fprintf(os.Stderr, "Ghi fired.json lỗi: %v\n", err)
		}
	}
}

// Xóa ID không còn trong schedule (khi Flutter regenerate file)
func cleanupFired(s *Schedule, f *FiredState) {
	valid := make(map[string]bool)
	for _, e := range s.Events {
		valid[e.ID] = true
	}
	newList := []string{}
	for _, id := range f.FiredIDs {
		if valid[id] {
			newList = append(newList, id)
		}
	}
	f.FiredIDs = newList
}

// ============================================================
// EXPIRY NOTIFICATION
// ============================================================

const expiredMarkerID = "__schedule_expired__"

func checkExpiry(s *Schedule, f *FiredState) {
	expiresAt, err := time.Parse(time.RFC3339, s.ExpiresAt)
	if err != nil {
		return
	}
	if time.Now().After(expiresAt) {
		if contains(f.FiredIDs, expiredMarkerID) {
			return // Đã gửi 1 lần rồi
		}
		_ = sendToast(
			"VIE Lịch",
			"Đã lâu chưa mở app. Mở VIE Lịch để cập nhật thông báo nhắc lịch.",
		)
		f.FiredIDs = append(f.FiredIDs, expiredMarkerID)
		_ = writeFired(f)
		fmt.Println("⚠️ Đã gửi cảnh báo schedule hết hạn")
	}
}

// ============================================================
// MAIN LOOP — dynamic sleep
// ============================================================

func loop() {
	var lastMtime time.Time

	for {
		schedule, err := readSchedule()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Đọc schedule lỗi: %v — ngủ 30s\n", err)
			time.Sleep(30 * time.Second)
			continue
		}

		// Phát hiện file thay đổi → cleanup fired IDs
		if info, err := os.Stat(getSchedulePath()); err == nil {
			if !info.ModTime().Equal(lastMtime) {
				f := readFired()
				cleanupFired(schedule, f)
				_ = writeFired(f)
				lastMtime = info.ModTime()
				fmt.Println("📄 schedule.json đã thay đổi — reload")
			}
		}

		// Check expiry
		f := readFired()
		checkExpiry(schedule, f)

		// Fire các event đến giờ
		processDue(schedule, f)

		// Tính thời gian ngủ tiếp
		f = readFired() // re-read sau khi processDue có thể đã ghi
		next, _ := findNextEvent(schedule, f)

		var sleepDur time.Duration
		if next.IsZero() {
			sleepDur = 60 * time.Second
		} else {
			until := time.Until(next)
			if until < 5*time.Second {
				until = 5 * time.Second
			}
			if until > 60*time.Second {
				until = 60 * time.Second
			}
			sleepDur = until
		}

		time.Sleep(sleepDur)
	}
}

// ============================================================
// MAIN
// ============================================================

func main() {
	// Đảm bảo thư mục tồn tại
	if err := os.MkdirAll(getAppDir(), 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Tạo thư mục lỗi: %v\n", err)
	}

	// Đăng ký AUMID — nếu lỗi vẫn tiếp tục (có thể đã đăng ký rồi)
	if err := registerAUMID(); err != nil {
		fmt.Fprintf(os.Stderr, "AUMID register: %v\n", err)
	}

	// Đăng ký auto-start
	if err := registerAutoStart(); err != nil {
		fmt.Fprintf(os.Stderr, "Auto-start register: %v\n", err)
	}

	fmt.Println("🚀 VIE Lịch Helper đã khởi động")
	fmt.Printf("   AppDir: %s\n", getAppDir())

	loop()
}