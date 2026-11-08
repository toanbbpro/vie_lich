#pragma once
#include <windows.h>
#include <string>

// Lightweight fallback for ATL's CW2A string conversion
// Used when Microsoft Visual Studio C++ ATL component is not installed.
class CW2A {
 public:
  explicit CW2A(LPCWSTR psz, UINT nCodePage = CP_UTF8) {
    if (!psz) {
      m_psz = nullptr;
      return;
    }
    int len = ::WideCharToMultiByte(nCodePage, 0, psz, -1, nullptr, 0, nullptr, nullptr);
    if (len > 0) {
      m_str.resize(len);
      ::WideCharToMultiByte(nCodePage, 0, psz, -1, &m_str[0], len, nullptr, nullptr);
      m_psz = m_str.c_str();
    } else {
      m_psz = "";
    }
  }
  operator LPCSTR() const { return m_psz ? m_psz : ""; }

 private:
  std::string m_str;
  const char* m_psz;
};
