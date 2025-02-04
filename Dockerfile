# Use the official ASP.NET Core runtime as a parent image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

# Use the official ASP.NET Core SDK as a build image
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["WebApplication/WebApplication.csproj", "WebApplication/"]
RUN dotnet restore "WebApplication/WebApplication.csproj"
COPY . .
WORKDIR "/src/WebApplication"
RUN dotnet build "WebApplication.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "WebApplication.csproj" -c Release -o /app/publish

# Copy the build output to the runtime image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "WebApplication.dll"]