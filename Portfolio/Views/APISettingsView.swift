import SwiftUI
import FirebaseAuth

// MARK: - API Settings View (Headless CMS)

struct APISettingsView: View {
    @Environment(AuthenticationService.self) private var authService
    
    @State private var copiedField: String?
    
    private var userUid: String {
        authService.currentUser?.uid ?? "NOT_SIGNED_IN"
    }
    
    private var projectId: String {
        authService.currentUser?.uid ?? ""
    }
    
private var firestoreEndpoint: String {
        "https://firestore.googleapis.com/v1/projects/portfolio-df758/databases/(default)/documents:runQuery"
    }
    
    private var publicProjectsQuery: String {
        """
        {
          "structuredQuery": {
            "from": [{"collectionId": "projects"}],
            "where": {
              "fieldFilter": {
                "field": {"fieldPath": "userId"},
                "op": "EQUAL",
                "value": {"stringValue": "\(userUid)"}
              }
            }
          }
        }
        """
    }
    
    private var curlExample: String {
        """
        curl -X POST \\
          '\(firestoreEndpoint)' \\
          -H 'Content-Type: application/json' \\
          -d '{
          "structuredQuery": {
            "from": [{"collectionId": "projects"}],
            "where": {
              "fieldFilter": {
                "field": {"fieldPath": "userId"},
                "op": "EQUAL",
                "value": {"stringValue": "\(userUid)"}
              }
            }
          }
        }'
        """
    }
    
    private var fetchExample: String {
        """
        const fetchProjects = async () => {
          const response = await fetch(
            '\(firestoreEndpoint)',
            {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                structuredQuery: {
                  from: [{ collectionId: 'projects' }],
                  where: {
                    fieldFilter: {
                      field: { fieldPath: 'userId' },
                      op: 'EQUAL',
                      value: { stringValue: '\(userUid)' }
                    }
                  }
                }
              })
            }
          );
          
          const data = await response.json();
          
          const projects = data
            .filter(item => item.document) 
            .map(item => item.document.fields);
            
          console.log(projects);
          return projects;
        };
        
        fetchProjects();
        """
    }
    
    var body: some View {
            List {
                // MARK: Your UID
                Section {
                    copyableRow(label: "User UID", value: userUid, fieldId: "uid")
                } header: {
                    Label("Your Identifier", systemImage: "key.fill")
                        .foregroundStyle(Color.headerInk)
                } footer: {
                    Text("This is your unique identifier. External apps use this UID to fetch your portfolio data.")
                }
                .listRowBackground(Color.surface)
                
                // MARK: API Endpoint
                Section {
                    copyableRow(label: "REST Endpoint", value: firestoreEndpoint, fieldId: "endpoint")
                } header: {
                    Label("VieFolio API Endpoint", systemImage: "server.rack")
                        .foregroundStyle(Color.headerInk)
                } footer: {
                    Text("Use this official VieFolio endpoint to seamlessly fetch your dynamic portfolio data into any web project.")
                }
                .listRowBackground(Color.surface)
                
                // MARK: cURL Example
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("cURL")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                            Spacer()
                            copyButton(text: curlExample, fieldId: "curl")
                        }
                        
                        Text(curlExample)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Example: cURL", systemImage: "terminal")
                        .foregroundStyle(Color.headerInk)
                }
                .listRowBackground(Color.surface)
                
                // MARK: JavaScript Example
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("JavaScript")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.yellow)
                            Spacer()
                            copyButton(text: fetchExample, fieldId: "js")
                        }
                        
                        Text(fetchExample)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Example: JavaScript", systemImage: "curlybraces")
                        .foregroundStyle(Color.headerInk)
                }
                .listRowBackground(Color.surface)
                
                // MARK: Query Body
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Request Body")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                            Spacer()
                            copyButton(text: publicProjectsQuery, fieldId: "query")
                        }
                        
                        Text(publicProjectsQuery)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Query Payload", systemImage: "doc.text")
                        .foregroundStyle(Color.headerInk)
                } footer: {
                    Text("VieFolio requires this structured JSON body to securely filter and return only your published projects.")
                }
                .listRowBackground(Color.surface)
            }
            .viefolioBackground()
            .navigationTitle("API Access")
    }
    
    // MARK: - Helper Views
    
    private func copyableRow(label: String, value: String, fieldId: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(1)
            }
            Spacer()
            copyButton(text: value, fieldId: fieldId)
        }
    }
    
    private func copyButton(text: String, fieldId: String) -> some View {
        Button {
            UIPasteboard.general.string = text
            withAnimation {
                copiedField = fieldId
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    if copiedField == fieldId {
                        copiedField = nil
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copiedField == fieldId ? "checkmark" : "doc.on.doc")
                if copiedField == fieldId {
                    Text("Copied!")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(copiedField == fieldId ? .green : .blue)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    APISettingsView()
        .environment(AuthenticationService())
}
