#include "base/file_name_utils.hpp"

#include "std/target_os.hpp"

using namespace std;

namespace base
{
void GetNameWithoutExt(string & name)
{
  string::size_type const i = name.rfind('.');
  if (i != string::npos)
    name.erase(i);
}

string FilenameWithoutExt(string name)
{
  GetNameWithoutExt(name);
  return name;
}

string GetFileExtension(string const & name)
{
  size_t const pos = name.find_last_of("./\\");
  return ((pos != string::npos && name[pos] == '.') ? name.substr(pos) : string());
}

void GetNameFromFullPath(string & name)
{
  string::size_type const i = name.find_last_of("/\\");
  if (i != string::npos)
    name = name.substr(i+1);
}

std::string GetNameFromFullPath(std::string const & path)
{
  std::string name = path;
  GetNameFromFullPath(name);
  return name;
}

string GetNameFromFullPathWithoutExt(string const & path)
{
  string name = path;
  GetNameFromFullPath(name);
  GetNameWithoutExt(name);
  return name;
}

string GetDirectory(string const & name)
{
  auto const sep = GetNativeSeparator();
  size_t const sepSize = sizeof(sep);

  string::size_type i = name.rfind(sep);
  if (i == string::npos)
    return ".";
  while (i > sepSize && (name[i - sepSize] == sep))
    i -= sepSize;
  return name.substr(0, i ? i : sepSize);
}

string::value_type GetNativeSeparator()
{
#ifdef OMIM_OS_WINDOWS
    return '\\';
#else
    return '/';
#endif
}

string AddSlashIfNeeded(string const & path)
{
  auto const sep = GetNativeSeparator();
  string::size_type const pos = path.rfind(sep);
  if ((pos != string::npos) && (pos + sizeof(sep) == path.size()))
    return path;
  return path + sep;
}
}  // namespace base
